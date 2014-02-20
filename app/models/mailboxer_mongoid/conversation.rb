class MailboxerMongoid::Conversation
  include Mongoid::Document
  include Mongoid::Timestamps

  NOTBOX = 1 # default and participant cannot view any messages
  TRASHBOX = 2
  SENTBOX = 4
  INBOX = 8
  INBOX_AND_SENTBOX = INBOX | SENTBOX

  CONVERSATION_UNREAD = 1
  CONVERSATION_READ = 2

  field :subject, type: String, default: ""


  attr_accessor :participants
  #attr_accessible :subject if MailboxerMongoid.protected_attributes?

  #embedded_in :mailbox, class_name: "MailboxerMongoid::Mailbox", inverse_of: :conversations
  #belongs_to :participant, :polymorphic => true

  has_many :messages, :dependent => :destroy, :class_name => "MailboxerMongoid::Message"
  embeds_many :participant_metadata, :class_name => "MailboxerMongoid::ParticipantMetadata", inverse_of: :conversation

  #has_many :receipts,  :class_name => "MailboxerMongoid::Receipt"#, cascade_callbacks: true
  scope :default_scope, ->{includes(:messages)}

  #index "messages.created_at" => -1
  #index "messages.receipts.created_at" => -1

  validates_presence_of :subject

  before_validation :clean

  scope :participant, lambda {|participant|
    where(:'participant_metadata'.elem_match => {:participant_id => participant.id}).desc(:created_at)
  }

  scope :inbox, lambda {|participant|
    where(:'participant_metadata'.elem_match =>
              {:participant_id => participant.id,
               :mailbox_type.in => [INBOX, INBOX_AND_SENTBOX]
              })
  }
  scope :sentbox, lambda {|participant|
    where(:'participant_metadata'.elem_match =>
              {:participant_id => participant.id,
               :mailbox_type.in => [SENTBOX, INBOX_AND_SENTBOX]
              })
  }
  scope :trash, lambda {|participant|
    where(:'participant_metadata'.elem_match =>
              {:participant_id => participant.id,
               :mailbox_type => TRASHBOX
              })
  }
  scope :unread,  lambda {|participant|
    where(:'participant_metadata'.elem_match =>
              {:participant_id => participant.id,
               :conversation_read => false
              })
  }
  scope :not_trash,  lambda {|participant|
    where('participant_metadata._type' => participant.class.to_s,
          'participant_metadata.participant_id' => participant.id)
  }

  class << self

    def exists?(id)
      MailboxerMongoid::Conversation.find(id).nil? == false
    end

    #def receipts_for(participant, options={})
    #  receipts = Array.new
    #  where(options).order_by(:created_at.desc, :'messages.created_at'.desc, :'messages.receipts.created_at'.desc).each do |convo|
    #    receipts << convo.receipts_for(participant)
    #  end
    #  #receipts = receipts.flatten
    #  where(options).messages.receipts.where(:receiver_id => participant.id)
    #end
  end

  #Mark the conversation as read for one of the participants
  def mark_as_read(participant)
    return unless participant
    participant_metadata.where(:participant_id => participant.id).update_all(:conversation_read => true)
    receipts_for(participant).mark_as_read
  end

  #Mark the conversation as unread for one of the participants
  def mark_as_unread(participant)
    return unless participant
    participant_metadata.where(:participant_id => participant.id).update_all(:conversation_read => false)
    receipts_for(participant).mark_as_unread
  end

  #Move the conversation to the trash for one of the participants
  def move_to_trash(participant)
    return unless participant
    participant_metadata.where(:participant_id => participant.id).update_all(:mailbox_type => TRASHBOX)
    receipts_for(participant).move_to_trash
  end

  #Takes the conversation out of the trash for one of the participants
  def untrash(participant)
    return unless participant
    receipts_for(participant).untrash
  end

  #Mark the conversation as deleted for one of the participants
  def mark_as_deleted(participant)
    return unless participant
    deleted_receipts = receipts_for(participant).mark_as_deleted
    remove_participant(participant)
    if is_orphaned?
      destroy
    else
      deleted_receipts
    end
  end

  def participants
    @participants ||= self.participant_metadata.collect do |metadata|
      klass = Object.const_get(metadata.participant_type)
      klass.find(metadata.participant_id)
    end

    @participants
  end

  def remove_participant(participant)
    self.participant_metadata.delete(self.participant_metadata.where(:participant_id => participant.id).first)
    if defined?(@participants)
      @participants = @participants.reject{|p| p.id == participant.id}
    end
  end

  #Returns an array of participants
  def recipients
    return [] unless original_message
    Array original_message.recipients.uniq
  end

  #Returns an array of participants
  #def participants
  #  recipients
  #end

  #Originator of the conversation.
  def originator
    @originator ||= self.original_message.sender
  end

  #First message of the conversation.
  def original_message
    @original_message ||= self.messages.sentbox.asc(:created_at).limit(1).first
  end

  #Sender of the last message.
  def last_sender
    @last_sender ||= self.last_message.sender
  end

  #Last message in the conversation.
  def last_message
    @last_message ||= self.messages.sentbox.desc(:created_at).limit(1).first
  end

  #Returns the receipts of the conversation for one participants
  def receipts_for(participant)
    MailboxerMongoid::Receipt.conversation(self).participant(participant)
  end

  #Returns the number of messages of the conversation
  def count_messages
    MailboxerMongoid::Message.conversation(self).count
  end

  #Returns true if the messageable is a participant of the conversation
  def is_participant?(participant)
    return false unless participant
    receipts_for(participant).count != 0
  end

	#Adds a new participant to the conversation
	def add_participant(participant, mailbox_type = INBOX)
    # Why unshift? b/c mailboxer spec included test that checked order and pushing
    # a participant here caused the test to fail. Not sure if this is important yet
    #self.participant_refs.unshift(participant.participator_reference)

    metadata = self.participant_metadata.new({
      :mailbox_type => mailbox_type
    })
    metadata.participant = participant

    # If the convo is already saved, save here.
    # If the convo is not saved, something else will save it later
    #if self.persisted?

    metadata.save
    #end

    if defined?(@participants)
      @participants << participant
    end

    #messages = MailboxerMongoid::Message.where(:conversation_id => self.id, :mailbox_type => 'sentbox')
    messages = self.messages.where(:mailbox_type => 'sentbox')
    messages.each do |message|
		  receipt = message.dup #MailboxerMongoid::Receipt.new
		  receipt.is_read = false
      receipt.trashed = false #needed?
		  receipt.recipient = participant
		  receipt.mailbox_type = 'inbox'
      receipt.save
    end

	end

  #Returns true if the participant has at least one trashed message of the conversation
  def is_trashed?(participant)
    return false unless participant
    self.receipts_for(participant).select{|receipt| receipt.trashed == false}.count != 0
  end

  #Returns true if the participant has deleted the conversation
  def is_deleted?(participant)
    return false unless participant
    #return self.receipts_for(participant).deleted.count == self.receipts_for(participant).count
    participants.find {|p| p.id == participant.id }.nil?
  end

  #Returns true if both participants have deleted the conversation
  def is_orphaned?
    #participants.reduce(true) do |is_orphaned, participant|
    #  is_orphaned && is_deleted?(participant)
    #end
    participants.length == 0
  end

  #Returns true if the participant has trashed all the messages of the conversation
  def is_completely_trashed?(participant)
    return false unless participant
    receipts_for(participant).select{|receipt| receipt.trashed == true}.count == receipts_for(participant).count
  end

  def is_read?(participant)
    !is_unread?(participant)
  end

  #Returns true if the participant has at least one unread message of the conversation
  def is_unread?(participant)
    return false unless participant
    receipts_for(participant).not_trash.is_unread.count != 0
  end

  protected

  #Use the default sanitize to clean the conversation subject
  def clean
    self.subject = sanitize subject
  end

  def sanitize(text)
    ::MailboxerMongoid::Cleaner.instance.sanitize(text)
  end
end
