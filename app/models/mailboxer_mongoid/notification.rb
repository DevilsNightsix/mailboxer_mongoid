class MailboxerMongoid::Notification
  include Mongoid::Document
  include Mongoid::Timestamps

  field :type, type: String
  field :body, type: String
  field :subject, type: String, default: ""

  field :nuid, type: BSON::ObjectId, default: BSON::ObjectId.new() #notification uid

  field :draft, type: Boolean, default: false
  field :notification_code, type: String, default: nil
  field :attachment, type: String
  field :global, type: Boolean, default: false
  field :expires, type: DateTime

  field :is_read, type: Boolean, default: false
  field :trashed, type: Boolean, default: false
  field :deleted, type: Boolean, default: false
  field :mailbox_type, type: String, default: nil

  attr_accessor :recipients
  #attr_accessible :body, :subject, :global, :expires if MailboxerMongoid.protected_attributes?

  #belongs_to :messageable, :polymorphic => true
  belongs_to :conversation, :class_name => "MailboxerMongoid::Conversation", :validate => true, :autosave => true
  belongs_to :notified_object, :polymorphic => true
  belongs_to :recipient, :polymorphic => true
  belongs_to :sender, :polymorphic => true

  def receiver
    recipient
  end

  def receiver=(receiver)
    self.recipient = receiver
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

    #This methods helps to do a update_all with table joins, not currently supported by rails.
    #Acording to the github ticket https://github.com/rails/rails/issues/522 it should be
    #supported with 3.2.
    def update_receipts(updates, options={})
      update_all(updates)
    end
  end


  #embeds_many :receipts, :class_name => "MailboxerMongoid::Receipt"#, cascade_callbacks: true
  #has_many :receipts, :class_name => "MailboxerMongoid::Receipt"#, cascade_callbacks: true

  validates_presence_of :subject, :body

  # return all notifications that were sent to recipient
  scope :recipient, lambda { |recipient|
    self.or({:recipient_id => recipient.id, :mailbox_type.in => ['inbox', nil]},
            {:sender_id => recipient.id, :mailbox_type => 'sentbox'}
    ).desc(:created_at)
  }

  scope :participant, lambda { |participant|
    self.or({:recipient_id => participant.id, :mailbox_type.in => ['inbox', nil]},
            {:sender_id => participant.id, :mailbox_type => 'sentbox'}
    ).desc(:created_at)
  }

  scope :with_object, lambda { |obj|
    where(:notified_object_id => obj.id, :notified_object_type => obj.class.to_s)
  }
  scope :not_trashed, lambda {
    raise "not useable yet"
    joins(:receipts).where('mailboxer_receipts.trashed' => false)
  }
  scope :unread,  lambda {
    #notification_ids = MailboxerMongoid::Receipt.where(is_read: false).collect {|receipt| receipt.notification.id}
    #self.in(id: notification_ids)
    where(:is_read => false)
  }

  scope :conversation, lambda {|conversation|
    where(:conversation_id => conversation.id).desc(:created_at)
  }

  scope :message_group, lambda {|notification|
    where(:nuid => notification.nuid)
  }

  scope :global, lambda { where(:global => true) }
  scope :expired, lambda { where(:expires.lt => Time.now) }
  scope :unexpired, lambda { self.or({:expires => nil}, {:expires.gt => Time.now}) }

  scope :sentbox, lambda { not_deleted.not_trash.where(:mailbox_type => "sentbox") }
  scope :inbox, lambda { not_deleted.not_trash.where(:mailbox_type => "inbox") }
  scope :trash, lambda { where(:trashed => true, :deleted => false) }
  scope :not_trash, lambda { where(:trashed => false) }
  scope :deleted, lambda { where(:deleted => true) }
  scope :not_deleted, lambda { where(:deleted => false) }
  scope :is_read, lambda { where(:is_read => true) }
  scope :is_unread, lambda { where(:is_read => false) }

  class << self
    #Sends a Notification to all the recipients
    def notify_all(recipients,subject,body,obj = nil,sanitize_text = true,notification_code=nil,send_mail=true)
      notification = MailboxerMongoid::Notification.new({:body => body, :subject => subject})
      notification.recipients        = Array(recipients).uniq
      notification.notified_object   = obj               if obj.present?
      notification.notification_code = notification_code if notification_code.present?
      notification.deliver sanitize_text, send_mail
    end

    #Takes a +Receipt+ or an +Array+ of them and returns +true+ if the delivery was
    #successful or +false+ if some error raised
    def successful_delivery? receipts
      case receipts
      when MailboxerMongoid::Receipt
        receipts.valid?
        receipts.errors.empty?
      when Array
        receipts.each(&:valid?)
        receipts.all? { |t| t.errors.empty? }
      else
        false
      end
    end
  end

  def expired?
    self.expires.present? && (self.expires < Time.now)
  end

  def expire!
    unless self.expired?
      self.expire
      self.save
    end
  end

  def expire
    unless self.expired?
      self.expires = Time.now - 1.second
    end
  end

  #Delivers a Notification. USE NOT RECOMENDED.
  #Use Mailboxer::Models::Message.notify and Notification.notify_all instead.
  def deliver(should_clean = true, send_mail = true)
    clean if should_clean
    #temp_receipts = Array.new

    #Receiver receipts
    temp_notifications = self.recipients.map do |r|
      notification = self.dup
      #notification.created_at = DateTime.now
      #notification.updated_at = DateTime.now
      notification.recipient = r
      notification
    end

    if temp_notifications.all?(&:valid?)
      temp_notifications.each(&:save!)   #Save receipts
      #MailboxerMongoid::MailDispatcher.new(self, recipients).call if send_mail
      self.recipients = nil
    end

    #return temp_notifications if temp_notifications.size > 1
    #temp_notifications.first
    receipts = temp_notifications.collect {|notif| build_receipt(notif, nil, false)}
    return receipts if receipts.size > 1
    receipts.first
  end

  #Returns the recipients of the Notification
  def recipients
    if @recipients.blank?
      self.conversation.participants
    else
      @recipients
    end
  end

  #Returns the receipt for the participant
  def receipt_for(participant)
    self
    #MailboxerMongoid::Receipt.notification(self).recipient(participant)
    #receipts.find_by()
    #receipts.find_by(:receiver_id => participant.id)
  end

  #Returns the receipt for the participant. Alias for receipt_for(participant)
  def receipts_for(participant)
    receipt_for(participant)
  end

  #Returns if the participant have read the Notification
  def is_unread?(participant)
    return false if participant.nil?
    !self.is_read#self.receipt_for(participant).first.is_read
  end

  def is_read?(participant)
    !self.is_unread?(participant)
  end

  #Returns if the participant have trashed the Notification
  def is_trashed?(participant)
    return false if participant.nil?
    self.receipt_for(participant).first.trashed
  end

  #Returns if the participant have deleted the Notification
  def is_deleted?(participant)
    return false if participant.nil?
    return self.deleted #self.receipt_for(participant).first.deleted
  end

  #Mark the notification as read
  def mark_as_read(participant)
    return if participant.nil?
    return self.update_attribute(:is_read, true)
    #self.receipt_for(participant).mark_as_read
  end

  #Mark the notification as unread
  def mark_as_unread(participant)
    return if participant.nil?
    #self.receipt_for(participant).mark_as_unread
    return self.update_attribute(:is_read, false)
  end

  #Move the notification to the trash
  def move_to_trash(participant)
    return if participant.nil?
    self.receipt_for(participant).move_to_trash
  end

  #Takes the notification out of the trash
  def untrash(participant)
    return if participant.nil?
    self.receipt_for(participant).untrash
  end

  #Mark the notification as deleted for one of the participant
  def mark_as_deleted(participant)
    return if participant.nil?
    #return self.receipt_for(participant).mark_as_deleted
    return self.update_attribute(:deleted, true)
  end

  #Sanitizes the body and subject
  def clean
    self.subject = sanitize(subject) if subject
    self.body    = sanitize(body)
  end

  #Returns notified_object. DEPRECATED
  def object
    warn "DEPRECATION WARNING: use 'notify_object' instead of 'object' to get the object associated with the Notification"
    notified_object
  end

  def sanitize(text)
    ::MailboxerMongoid::Cleaner.instance.sanitize(text)
  end

  protected

  def build_receipt(receiver, mailbox_type, is_read = false)
    self.becomes(MailboxerMongoid::Receipt)
  end

end
