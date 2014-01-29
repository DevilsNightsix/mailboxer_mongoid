class Duck
  include Mongoid::Document
  include Mongoid::Timestamps
  acts_as_messageable

  field :name, type: String
  field :email, type: String


  def mailboxer_email(object)
    case object
    when MailboxerMongoid::Message
      return nil
    when MailboxerMongoid::Notification
      return email
    end
  end
end
