class User
  include Mongoid::Document
  include Mongoid::Timestamps
  acts_as_messageable

  field :name, type: String
  field :email, type: String

  def mailboxer_email(object)
    return email
  end
end
