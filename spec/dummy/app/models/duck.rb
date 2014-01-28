class Duck
  include Mongoid::Document
  include Mongoid::Timestamps
  acts_as_messageable

  field :name, type: String
  field :email, type: String


  def mailboxer_email(object)
    case object
    when Mailboxer::Message
      return nil
    when Mailboxer::Notification
      return email
    end
  end
end
