class MailboxerMongoid::Receipt
  include Mongoid::Document
  include Mongoid::Timestamps

  field :is_read, type: Boolean, default: false
  field :trashed, type: Boolean, default: false
  field :deleted, type: Boolean, default: false
  field :mailbox_type, type: String


  attr_accessible :trashed, :is_read, :deleted if MailboxerMongoid.protected_attributes?

  #embedded_in :conversation, class_name: "MailboxerMongoid::Conversation", inverse_of: :receipts
  #embedded_in :notification, :class_name => "MailboxerMongoid::Notification"#, :validate => true
   #belongs_to :notification, :class_name => "MailboxerMongoid::Notification", :validate => true, :autosave => true
  belongs_to :receiver, :polymorphic => true
  embedded_in :notification, :class_name => "MailboxerMongoid::Notification"#, :foreign_key => "notification_id"
  #belongs_to :message, :class_name => "MailboxerMongoid::Message", :foreign_key => "notification_id"


  def message
    notification
  end


  validates_presence_of :receiver

  #def self.recipient(recipient)
  scope :recipient, lambda {|recipient|
    MailboxerMongoid::Conversation.participant(recipient)#.receipts_for(recipient)
  }

  def self.conversation(conversation)
    MailboxerMongoid::Conversation.where(:_id => conversation._id)#.order_by(:'comments.updated_at'.asc)
  end

  #Notifications Scope checks type to be nil, not Notification because of STI behaviour
  #with the primary class (no type is saved)
  scope :notifications_receipts, lambda {
    raise 'cannot use notification receipts yet'
    joins(:notification).where('mailboxer_notifications.type' => nil) }
  scope :messages_receipts, lambda {
    raise 'cannot use messages receipts yet'
    joins(:notification).where('mailboxer_notifications.type' => MailboxerMongoid::Message.to_s) }
  #scope :notification, lambda { |notification|
  #  where(:notification_id => notification.id)
  #}

  scope :sentbox, lambda { where(:mailbox_type => "sentbox").asc(:updated_at) }
  scope :inbox, lambda { where(:mailbox_type => "inbox") }
  scope :trash, lambda { where(:trashed => true, :deleted => false) }
  scope :not_trash, lambda { where(:trashed => false) }
  scope :deleted, lambda { where(:deleted => true) }
  scope :not_deleted, lambda { where(:deleted => false) }
  scope :is_read, lambda { where(:is_read => true) }
  scope :is_unread, lambda { where(:is_read => false) }

  after_validation :remove_duplicate_errors
  class << self
    #Marks all the receipts from the relation as read
    def mark_as_read(receipts, options={})
      update_receipts(receipts, {:is_read => true}, options)
      #receipts.each {|receipt| receipt.is_read = true}
    end

    #Marks all the receipts from the relation as unread
    def mark_as_unread(receipts, options={})
      update_receipts(receipts, {:is_read => false}, options)
      #receipts.each {|receipt| receipt.is_read = false}
    end

    #Marks all the receipts from the relation as trashed
    def move_to_trash(receipts, options={})
      update_receipts(receipts, {:trashed => true}, options)
      #receipts.each {|receipt| receipt.trashed = true}
    end

    #Marks all the receipts from the relation as not trashed
    def untrash(receipts, options={})
      update_receipts(receipts, {:trashed => false}, options)
      #receipts.each {|receipt| receipt.trashed = false}
    end

    #Marks the receipt as deleted
    def mark_as_deleted(receipts, options={})
      update_receipts(receipts, {:deleted => true}, options)
      #receipts.each {|receipt| receipt.deleted = true}
    end

    #Marks the receipt as not deleted
    def mark_as_not_deleted(receipts, options={})
      update_receipts(receipts, {:deleted => false}, options)
      #receipts.each {|receipt| receipt.deleted = false}
    end

    def has_unread?(receipts, options={})
      receipts.reduce(false) {|has_unread, receipt| has_unread || !receipt.is_read }
    end

    #Moves all the receipts from the relation to inbox
    def move_to_inbox(receipts, options={})
      update_receipts(receipts, {:mailbox_type => :inbox, :trashed => false}, options)
    end

    #Moves all the receipts from the relation to sentbox
    def move_to_sentbox(receipts, options={})
      update_receipts(receipts, {:mailbox_type => :sentbox, :trashed => false}, options)
    end

    #This methods helps to do a update_all with table joins, not currently supported by rails.
    #Acording to the github ticket https://github.com/rails/rails/issues/522 it should be
    #supported with 3.2.
    def update_receipts(receipts, updates, options={})

      ids = receipts.collect {|receipt| receipt.id}
      conversation = receipts.first.message.conversation

      unless ids.empty?
        MailboxerMongoid::Conversation.where(:_id => conversation.id, :'messages.receipts._id'.in => ids).update_all(updates)
        #self.in(id: ids).update_all(updates)
      end
    end
  end


  #Marks the receipt as deleted
  def mark_as_deleted
    update_attributes(:deleted => true)
  end

  #Marks the receipt as not deleted
  def mark_as_not_deleted
    update_attributes(:deleted => false)
  end

  #Marks the receipt as read
  def mark_as_read
    update_attributes(:is_read => true)
  end

  #Marks the receipt as unread
  def mark_as_unread
    update_attributes(:is_read => false)
  end

  #Marks the receipt as trashed
  def move_to_trash
    update_attributes(:trashed => true)
  end

  #Marks the receipt as not trashed
  def untrash
    update_attributes(:trashed => false)
  end

  #Moves the receipt to inbox
  def move_to_inbox
    update_attributes(:mailbox_type => :inbox, :trashed => false)
  end

  #Moves the receipt to sentbox
  def move_to_sentbox
    update_attributes(:mailbox_type => :sentbox, :trashed => false)
  end

  #Returns the conversation associated to the receipt if the notification is a Message
  def conversation
    message.conversation if message.is_a? MailboxerMongoid::Message
  end

  #Returns if the participant have read the Notification
  def is_unread?
    !self.is_read
  end

  #Returns if the participant have trashed the Notification
  def is_trashed?
    self.trashed
  end

  protected

  #Removes the duplicate error about not present subject from Conversation if it has been already
  #raised by Message
  def remove_duplicate_errors
    if self.errors["mailboxer_notification.conversation.subject"].present? and self.errors["mailboxer_notification.subject"].present?
      self.errors["mailboxer_notification.conversation.subject"].each do |msg|
        self.errors["mailboxer_notification.conversation.subject"].delete(msg)
      end
    end
  end

  if MailboxerMongoid.search_enabled
    searchable do
      text :subject, :boost => 5 do
        message.subject if message
      end
      text :body do
        message.body if message
      end
      integer :receiver_id
    end
  end
end
