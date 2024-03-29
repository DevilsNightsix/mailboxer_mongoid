module MailboxerMongoid
  module Models
    module Messageable
      extend ActiveSupport::Concern

      module MongoidExtension
        #Converts the model into messageable allowing it to interchange messages and
        #receive notifications
        def acts_as_messageable
          include Messageable
        end
      end

      included do
        has_many :messages, :class_name => "MailboxerMongoid::Message", :as => :sender
        has_many :receipts, :class_name => "MailboxerMongoid::Receipt", dependent: :destroy, as: :receiver
      end

      unless defined?(MailboxerMongoid.name_method)
        # Returning any kind of identification you want for the model
        define_method MailboxerMongoid.name_method do
          begin
            super
          rescue NameError
            return "You should add method :#{MailboxerMongoid.name_method} in your Messageable model"
          end
        end
      end

      unless defined?(MailboxerMongoid.email_method)
        #Returning the email address of the model if an email should be sent for this object (Message or Notification).
        #If no mail has to be sent, return nil.
        define_method MailboxerMongoid.email_method do |object|
          begin
            super
          rescue NameError
            return "You should add method :#{MailboxerMongoid.email_method} in your Messageable model"
          end
        end
      end

      #Gets the mailbox of the messageable
      def mailbox
        @mailbox = MailboxerMongoid::Mailbox.new(self) if @mailbox.nil?
        @mailbox.type = :all
        @mailbox
      end

      #Sends a notification to the messageable
      def notify(subject,body,obj = nil,sanitize_text=true,notification_code=nil,send_mail=true)
        MailboxerMongoid::Notification.notify_all([self],subject,body,obj,sanitize_text,notification_code,send_mail)
      end

      #Sends a messages, starting a new conversation, with the messageable
      #as originator
      def send_message(recipients, msg_body, subject, sanitize_text=true, attachment=nil, message_timestamp = Time.now)
        convo = MailboxerMongoid::Conversation.new({:subject => subject})
        convo.created_at = message_timestamp
        convo.updated_at = message_timestamp
        message = messages.new({:body => msg_body, :subject => subject, :attachment => attachment})
        message.created_at = message_timestamp
        message.updated_at = message_timestamp
        message.conversation = convo
        message.recipients = recipients.is_a?(Array) ? recipients : [recipients]
        message.recipients = message.recipients.uniq
        receipt = message.deliver false, sanitize_text
        receipt
      end

      #Basic reply method. USE NOT RECOMENDED.
      #Use reply_to_sender, reply_to_all and reply_to_conversation instead.
      def reply(conversation, recipients, reply_body, subject=nil, sanitize_text=true, attachment=nil)
        subject = subject || "RE: #{conversation.subject}"
        response = messages.new({:body => reply_body, :subject => subject, :attachment => attachment})
        response.created_at = Time.now
        response.updated_at = Time.now
        response.conversation = conversation
        response.recipients = recipients.is_a?(Array) ? recipients : [recipients]
        response.recipients = response.recipients.uniq
        response.recipients.delete(self)
        response.deliver true, sanitize_text
      end

      #Replies to the sender of the message in the conversation
      def reply_to_sender(receipt, reply_body, subject=nil, sanitize_text=true, attachment=nil)
        reply(receipt.conversation, receipt.message.sender, reply_body, subject, sanitize_text, attachment)
      end

      #Replies to all the recipients of the message in the conversation
      def reply_to_all(receipt, reply_body, subject=nil, sanitize_text=true, attachment=nil)
        reply(receipt.conversation, receipt.message.recipients, reply_body, subject, sanitize_text, attachment)
      end

      #Replies to all the recipients of the last message in the conversation and untrash any trashed message by messageable
      #if should_untrash is set to true (this is so by default)
      def reply_to_conversation(conversation, reply_body, subject=nil, should_untrash=true, sanitize_text=true, attachment=nil)
        #move conversation to inbox if it is currently in the trash and should_untrash parameter is true.
        if should_untrash && mailbox.is_trashed?(conversation)
          mailbox.receipts_for(conversation).untrash
          mailbox.receipts_for(conversation).mark_as_not_deleted
        end

        reply(conversation, conversation.last_message.recipients, reply_body, subject, sanitize_text, attachment)
      end

      #Mark the object as read for messageable.
      #
      #Object can be:
      #* A Receipt
      #* A Message
      #* A Notification
      #* A Conversation
      #* An array with any of them
      def mark_as_read(obj)
        case obj
        when MailboxerMongoid::Receipt
          obj.mark_as_read if obj.receiver == self
        when MailboxerMongoid::Message, MailboxerMongoid::Notification
          obj.mark_as_read(self)
        when MailboxerMongoid::Conversation
          obj.mark_as_read(self)
        when Array
          obj.map{ |sub_obj| mark_as_read(sub_obj) }
        end
      end

      #Mark the object as unread for messageable.
      #
      #Object can be:
      #* A Receipt
      #* A Message
      #* A Notification
      #* A Conversation
      #* An array with any of them
      def mark_as_unread(obj)
        case obj
        when MailboxerMongoid::Receipt
          obj.mark_as_unread if obj.receiver == self
        when MailboxerMongoid::Message, MailboxerMongoid::Notification
          obj.mark_as_unread(self)
        when MailboxerMongoid::Conversation
          obj.mark_as_unread(self)
        when Array
          obj.map{ |sub_obj| mark_as_unread(sub_obj) }
        end
      end

      #Mark the object as deleted for messageable.
      #
      #Object can be:
      #* A Receipt
      #* A Notification
      #* A Message
      #* A Conversation
      #* An array with any of them
      def mark_as_deleted(obj)
        case obj
          when Receipt
            return obj.mark_as_deleted if obj.receiver == self
          when Message, Notification
            obj.mark_as_deleted(self)
          when Conversation
            obj.mark_as_deleted(self)
          when Array
            obj.map{ |sub_obj| mark_as_deleted(sub_obj) }
          else
            return nil
        end
      end

      #Mark the object as trashed for messageable.
      #
      #Object can be:
      #* A Receipt
      #* A Message
      #* A Notification
      #* A Conversation
      #* An array with any of them
      def trash(obj)
        case obj
        when MailboxerMongoid::Receipt
          obj.move_to_trash if obj.receiver == self
        when MailboxerMongoid::Message, MailboxerMongoid::Notification
          obj.move_to_trash(self)
        when MailboxerMongoid::Conversation
          obj.move_to_trash(self)
        when Array
          obj.map{ |sub_obj| trash(sub_obj) }
        end
      end

      #Mark the object as not trashed for messageable.
      #
      #Object can be:
      #* A Receipt
      #* A Message
      #* A Notification
      #* A Conversation
      #* An array with any of them
      def untrash(obj)
        case obj
        when MailboxerMongoid::Receipt
          obj.untrash if obj.receiver == self
        when MailboxerMongoid::Message, MailboxerMongoid::Notification
          obj.untrash(self)
        when MailboxerMongoid::Conversation
          obj.untrash(self)
        when Array
          obj.map{ |sub_obj| untrash(sub_obj) }
        end
      end

      def search_messages(query)
        raise "not ready for use"
        @search = MailboxerMongoid::Receipt.search do
          fulltext query
          with :receiver_id, self.id
        end

        @search.results.map { |r| r.conversation }.uniq
      end
    end
  end
end
