class MailboxerMongoid::Conversation
  include Mongoid::Document
  include Mongoid::Timestamps

  field :subject, type: String, default: ""

  attr_accessible :subject if MailboxerMongoid.protected_attributes?

  has_many :messages, :dependent => :destroy, :class_name => "MailboxerMongoid::Message"
  #has_many :receipts, :through => :messages, :class_name => "MailboxerMongoid::Receipt"

  validates_presence_of :subject

  before_validation :clean

  scope :participant, lambda {|participant|
    receipts = MailboxerMongoid::Receipt.recipient(participant)
    conversation_ids = receipts.collect {|receipt| receipt.message.conversation_id }
    self.in(id: conversation_ids).desc(:updated_at)
  }
  scope :inbox, lambda {|participant|
    receipts = MailboxerMongoid::Receipt.recipient(participant).inbox.not_trash.not_deleted
    conversation_ids = receipts.collect {|receipt| receipt.message.conversation_id }
    self.in(id: conversation_ids).desc(:updated_at)
  }
  scope :sentbox, lambda {|participant|
    receipts = MailboxerMongoid::Receipt.recipient(participant).sentbox.not_trash.not_deleted
    conversation_ids = receipts.collect {|receipt| receipt.message.conversation_id }
    self.in(id: conversation_ids).desc(:updated_at)
  }
  scope :trash, lambda {|participant|
    receipts = MailboxerMongoid::Receipt.recipient(participant).trash
    conversation_ids = receipts.collect {|receipt| receipt.message.conversation_id }
    self.in(id: conversation_ids).desc(:updated_at)
  }
  scope :unread,  lambda {|participant|
    receipts = MailboxerMongoid::Receipt.recipient(participant).is_unread
    conversation_ids = receipts.collect {|receipt| receipt.message.conversation_id }
    self.in(id: conversation_ids).desc(:updated_at)
  }
  scope :not_trash,  lambda {|participant|
    receipts = MailboxerMongoid::Receipt.recipient(participant).not_trash
    conversation_ids = receipts.collect {|receipt| receipt.message.conversation_id }
    self.in(id: conversation_ids).desc(:updated_at)
  }

  #Mark the conversation as read for one of the participants
  def mark_as_read(participant)
    return unless participant
    receipts_for(participant).mark_as_read
  end

  #Mark the conversation as unread for one of the participants
  def mark_as_unread(participant)
    return unless participant
    receipts_for(participant).mark_as_unread
  end

  #Move the conversation to the trash for one of the participants
  def move_to_trash(participant)
    return unless participant
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
    if is_orphaned?
      destroy
    else
      deleted_receipts
    end
  end

  #Returns an array of participants
  def recipients
    return [] unless original_message
    Array original_message.recipients
  end

  #Returns an array of participants
  def participants
    recipients
  end

  #Originator of the conversation.
  def originator
    @originator ||= self.original_message.sender
  end

  #First message of the conversation.
  def original_message
    @original_message ||= self.messages.asc(:created_at).first
  end

  #Sender of the last message.
  def last_sender
    @last_sender ||= self.last_message.sender
  end

  #Last message in the conversation.
  def last_message
    @last_message ||= self.messages.desc(:created_at).first
  end

  #Returns the receipts of the conversation for one participants
  def receipts_for(participant)
    MailboxerMongoid::Receipt.conversation(self).recipient(participant)
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
		messages = self.messages
		messages.each do |message|
		  receipt = MailboxerMongoid::Receipt.new
		  receipt.notification = message
		  receipt.is_read = false
		  receipt.receiver = participant
		  receipt.mailbox_type = 'inbox'
		  receipt.updated_at = message.updated_at
		  receipt.created_at = message.created_at
		  receipt.save
		end
	end

  #Returns true if the participant has at least one trashed message of the conversation
  def is_trashed?(participant)
    return false unless participant
    self.receipts_for(participant).trash.count != 0
  end

  #Returns true if the participant has deleted the conversation
  def is_deleted?(participant)
    return false unless participant
    return self.receipts_for(participant).deleted.count == self.receipts_for(participant).count
  end

  #Returns true if both participants have deleted the conversation
  def is_orphaned?
    participants.reduce(true) do |is_orphaned, participant|
      is_orphaned && is_deleted?(participant)
    end
  end

  #Returns true if the participant has trashed all the messages of the conversation
  def is_completely_trashed?(participant)
    return false unless participant
    receipts_for(participant).trash.count == receipts_for(participant).count
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
