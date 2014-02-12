class MailboxerMongoid::Conversation
  include Mongoid::Document
  include Mongoid::Timestamps

  field :subject, type: String, default: ""

  field :participant_refs, type: Array, default: []

  #attr_accessible :subject if MailboxerMongoid.protected_attributes?

  #embedded_in :mailbox, class_name: "MailboxerMongoid::Mailbox", inverse_of: :conversations
  #belongs_to :participant, :polymorphic => true
  embeds_many :messages, :class_name => "MailboxerMongoid::Message"#, cascade_callbacks: true
  #embeds_many :receipts,  :class_name => "MailboxerMongoid::Receipt", cascade_callbacks: true

  validates_presence_of :subject

  before_validation :clean

  def participant_refs=(p)
    self[:participant_refs] = p.collect {|participant| participant.participator_reference }
  end


  scope :participant, lambda {|participant|
    #receipts = MailboxerMongoid::Receipt.recipient(participant)
    #conversation_ids = receipts.collect {|receipt| receipt.message.conversation_id }
    #self.in(id: conversation_ids).desc(:updated_at)
    where(:'participant_refs'.elem_match => {:_type => participant.class.to_s, :participant_id => participant.id}).desc(:updated_at)
  }

  scope :inbox, lambda {|participant|
    where('participant_refs._type' => participant.class.to_s,
          'participant_refs.participant_id' => participant.id,
          :'messages.receipts'.elem_match => {'receiver_id' => participant.id, 'mailbox_type' => 'inbox'}
    ).desc(:updated_at)
  }
  scope :sentbox, lambda {|participant|
    where('participant_refs._type' => participant.class.to_s,
          'participant_refs.participant_id' => participant.id,
          :'messages.receipts'.elem_match => {'receiver_id' => participant.id, 'mailbox_type' => 'sentbox'}
    ).desc(:updated_at)
  }
  scope :trash, lambda {|participant|
    where('participant_refs._type' => participant.class.to_s,
          'participant_refs.participant_id' => participant.id,
          :'messages.receipts'.elem_match => {'receiver_id' => participant.id, 'trashed' => false}
    ).desc(:updated_at)
  }
  scope :unread,  lambda {|participant|
    where('participant_refs._type' => participant.class.to_s,
          'participant_refs.participant_id' => participant.id,
          :'messages.receipts'.elem_match => {'receiver_id' => participant.id, 'is_read' => false}
    ).desc(:updated_at)
  }
  scope :not_trash,  lambda {|participant|
    where('participant_refs._type' => participant.class.to_s,
          'participant_refs.participant_id' => participant.id,
          :'messages.receipts'.elem_match => {'receiver_id' => participant.id, 'trashed' => false}
    ).desc(:updated_at)
  }

  #Mark the conversation as read for one of the participants
  def mark_as_read(participant)
    return unless participant
    MailboxerMongoid::Receipt.mark_as_read(receipts_for(participant))
    save
  end

  #Mark the conversation as unread for one of the participants
  def mark_as_unread(participant)
    return unless participant
    MailboxerMongoid::Receipt.mark_as_unread(receipts_for(participant))
    save
  end

  #Move the conversation to the trash for one of the participants
  def move_to_trash(participant)
    return unless participant
    MailboxerMongoid::Receipt.move_to_trash(receipts_for(participant))
    save
  end

  #Takes the conversation out of the trash for one of the participants
  def untrash(participant)
    return unless participant
    MailboxerMongoid::Receipt.untrash(receipts_for(participant))
    save
  end

  #Mark the conversation as deleted for one of the participants
  def mark_as_deleted(participant)
    return unless participant
    deleted_receipts = MailboxerMongoid::Receipt.mark_as_deleted(receipts_for(participant))
    remove_participant(participant)

    if is_orphaned?
      destroy
    else
      deleted_receipts
    end
  end

  def participants
    @participants ||= self[:participant_refs].collect do |participant|
      klass = Object.const_get(participant[:_type])
      klass.find(participant[:participant_id])
    end

    @participants
  end

  def remove_participant(participant)
    self.participant_refs.reject! {|p| p[:participant_id] == participant.id}
    if defined?(@participants)
      #if the partipators have already been queried for, reject here too
      @participants.reject!{|p| p.id == participant.id}
    end

  end

  #Returns an array of participants
  def recipients()
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
    @original_message ||= self.messages.first #self.messages.asc(:created_at).first
  end

  #Sender of the last message.
  def last_sender
    @last_sender ||= self.last_message.sender
  end

  #Last message in the conversation.
  def last_message

    @last_message ||= self.messages.last #.desc(:created_at).first
  end

  #Returns the receipts of the conversation for one participants
  def receipts_for(participant)
    #MailboxerMongoid::Receipt.conversation(self).recipient(participant)
    messages.collect {|message| message.receipt_for(participant)}
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
	def add_participant(participant)
    # Why unshift? b/c mailboxer spec included test that checked order and pushing
    # a participant here caused the test to fail. Not sure if this is important yet
    self.participant_refs.unshift(participant.participator_reference)
    if defined?(@participants)
      @participants << participant
    end
    messages = self.messages
		messages.each do |message|
		  receipt = MailboxerMongoid::Receipt.new
		  #receipt.notification = message
		  receipt.is_read = false
		  receipt.receiver = participant
		  receipt.mailbox_type = 'inbox'
      message.receipts << receipt
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
    return participants.find {|p| p.id == participant.id }.nil?
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
    #receipts_for(participant).not_trash.is_unread.count != 0
    MailboxerMongoid::Receipt.has_unread?(receipts_for(participant))
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
