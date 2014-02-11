class MailboxerMongoid::Receipt
  include Mongoid::Document
  include Mongoid::Timestamps

  field :is_read, type: Boolean, default: false
  field :trashed, type: Boolean, default: false
  field :deleted, type: Boolean, default: false
  field :mailbox_type, type: String

  #field :receiver, type: BSON::ObjectId

  attr_accessible :trashed, :is_read, :deleted if MailboxerMongoid.protected_attributes?

  embedded_in :notification, :class_name => "MailboxerMongoid::Notification", :validate => true
   #belongs_to :notification, :class_name => "MailboxerMongoid::Notification", :validate => true, :autosave => true
  belongs_to :receiver, :polymorphic => true
  belongs_to :message, :class_name => "MailboxerMongoid::Message", :foreign_key => "notification_id"



  validates_presence_of :receiver

  scope :recipient, lambda { |recipient|
    where(:receiver_id => recipient.id.to_s, :receiver_type => recipient.class.to_s)
  }
  #Notifications Scope checks type to be nil, not Notification because of STI behaviour
  #with the primary class (no type is saved)
  scope :notifications_receipts, lambda {
    raise 'cannot use notification receipts yet'
    joins(:notification).where('mailboxer_notifications.type' => nil) }
  scope :messages_receipts, lambda {
    raise 'cannot use messages receipts yet'
    joins(:notification).where('mailboxer_notifications.type' => MailboxerMongoid::Message.to_s) }
  scope :notification, lambda { |notification|
    where(:notification_id => notification.id)
  }
  scope :conversation, lambda { |conversation|
    messages = MailboxerMongoid::Message.where(:conversation_id => conversation.id.to_s)
    messages_ids = messages.collect {|message| message.id.to_s}
    self.in(notification_id: messages_ids)
  }
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
    def mark_as_read(options={})
      update_receipts({:is_read => true}, options)
    end

    #Marks all the receipts from the relation as unread
    def mark_as_unread(options={})
      update_receipts({:is_read => false}, options)
    end

    #Marks all the receipts from the relation as trashed
    def move_to_trash(options={})
      update_receipts({:trashed => true}, options)
    end

    #Marks all the receipts from the relation as not trashed
    def untrash(options={})
      update_receipts({:trashed => false}, options)
    end

    #Marks the receipt as deleted
    def mark_as_deleted(options={})
      update_receipts({:deleted => true}, options)
    end

    #Marks the receipt as not deleted
    def mark_as_not_deleted(options={})
      update_receipts({:deleted => false}, options)
    end

    #Moves all the receipts from the relation to inbox
    def move_to_inbox(options={})
      update_receipts({:mailbox_type => :inbox, :trashed => false}, options)
    end

    #Moves all the receipts from the relation to sentbox
    def move_to_sentbox(options={})
      update_receipts({:mailbox_type => :sentbox, :trashed => false}, options)
    end

    #This methods helps to do a update_all with table joins, not currently supported by rails.
    #Acording to the github ticket https://github.com/rails/rails/issues/522 it should be
    #supported with 3.2.
    def update_receipts(updates,options={})
      ids = Array.new

      where(options).each do |rcp|
        ids << rcp.id
      end

      unless ids.empty?
        self.in(id: ids).update_all(updates)
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
