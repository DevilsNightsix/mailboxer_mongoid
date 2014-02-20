class MailboxerMongoid::Message < MailboxerMongoid::Notification
  include Mongoid::Document

  # @TODO
  #attr_accessible :attachment if Mailboxer.protected_attributes?

  validates_presence_of :sender

  belongs_to :conversation, :class_name => "MailboxerMongoid::Conversation", :validate => true, :autosave => true

  class_attribute :on_deliver_callback
  protected :on_deliver_callback

  index :created_at => 1

  # @TODO -> gridfs?
  #mount_uploader :attachment, AttachmentUploader

  class << self
    #Sets the on deliver callback method.
    def on_deliver(callback_method)
      self.on_deliver_callback = callback_method
    end
  end

  #Delivers a Message. USE NOT RECOMENDED.
  #Use Mailboxer::Models::Message.send_message instead.
  def deliver(reply = false, should_clean = true)
    self.clean if should_clean

    temp_messages = recipients.collect do |r|
      message = self.dup
      message.recipient = r
      message.mailbox_type = 'inbox'
      message
    end


    #Sender receipt
    sender_receipt = build_receipt(sender, 'sentbox', true)

    #temp_receipts << sender_receipt

    if temp_messages.all?(&:valid?)
      temp_messages.each(&:save!) 	#Save receipts

      #MailboxerMongoid::MailDispatcher.new(self, recipients).call

      conversation.touch if reply

      self.recipients = nil

      on_deliver_callback.call(self) if on_deliver_callback
    end

    sender_receipt
  end


end
