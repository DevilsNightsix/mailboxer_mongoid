class MailboxerMongoid::Receipt < MailboxerMongoid::Message
  include Mongoid::Document
  acts_as_proxy MailboxerMongoid::Message, MailboxerMongoid::Notification

  scope :participant, lambda { |participant|
    where(:_type.in => ['MailboxerMongoid::Message','MailboxerMongoid::Notification', nil]).or({:recipient_id => participant.id, :mailbox_type.in => ['inbox', nil]},
            {:sender_id => participant.id, :mailbox_type => 'sentbox'}
    ).desc(:created_at)
  }

  scope :conversation, lambda {|conversation|
    where(:conversation_id => conversation.id, :_type => 'MailboxerMongoid::Message').desc(:created_at)
  }

  #store_in({:collection => "mailboxer_mongoid_notifications"})
  #attr_accessible :trashed, :is_read, :deleted if MailboxerMongoid.protected_attributes?


  def message
    self.becomes(MailboxerMongoid::Message)
  end

  def notification
    return self.becomes(MailboxerMongoid::Notification) if self.conversation_id.nil?
    return message
  end

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

    def update_receipts(updates, options={})
      update_all(updates)
    end
  end

  # Multiple messages are created and sent to each participant
  # A receipt is generated for a single message, but can be used to
  # modify all messages that were generated from a send_message, notify,
  # or reply command. As such, the notification bound to this receipt
  # may not be the receipt for a specific participant's equivalent notification.
  # participant_notification returns the correct notification criteria that will
  # allow a specific notification to be updated, changed, or deleted
  def participant_notification(participant)
    if notification.mailbox_type == 'sentbox' && notficiation.sender_id == participant.id
      return notification
    elsif ['inbox', nil].include?(notification.mailbox_type) && notification.recipient_id == participant.id
      return notification
    else
      return MailboxerMongoid::Notification.participant(participant).message_group(notification)
    end
  end

  #Marks the receipt as deleted
  def mark_as_deleted
    participant_notification(participant).update_all(:deleted => true)
  end

  #Marks the receipt as not deleted
  def mark_as_not_deleted
    participant_notification(participant).update_all(:deleted => false)
  end

  #Marks the receipt as read
  def mark_as_read(participant)
    participant_notification(participant).update_all(:is_read => true)
  end

  #Marks the receipt as unread
  def mark_as_unread
    participant_notification(participant).update_all(:is_read => false)
  end

  #Marks the receipt as trashed
  def move_to_trash
    participant_notification(participant).update_all(:trashed => true)
  end

  #Marks the receipt as not trashed
  def untrash
    participant_notification(participant).update_all(:trashed => false)
  end

  #Moves the receipt to inbox
  def move_to_inbox
    participant_notification(participant).update_all(:mailbox_type => :inbox, :trashed => false)
  end

  #Moves the receipt to sentbox
  def move_to_sentbox
    participant_notification(participant).update_all(:mailbox_type => :sentbox, :trashed => false)
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
