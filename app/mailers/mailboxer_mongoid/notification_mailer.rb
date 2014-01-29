class MailboxerMongoid::NotificationMailer < MailboxerMongoid::BaseMailer
  #Sends and email for indicating a new notification to a receiver.
  #It calls new_notification_email.
  def send_email(notification, receiver)
    new_notification_email(notification, receiver)
  end

  #Sends an email for indicating a new message for the receiver
  def new_notification_email(notification, receiver)
    @notification = notification
    @receiver     = receiver
    set_subject(notification)
    mail :to => receiver.send(MailboxerMongoid.email_method, notification),
         :subject => t('mailboxer_mongoid.notification_mailer.subject', :subject => @subject),
         :template_name => 'new_notification_email'
  end
end
