class Cylon
  include Mongoid::Document
  include Mongoid::Timestamps
  acts_as_messageable


  field :name, type: String
  field :email, type: String

  def mailboxer_email(object)
    return nil
  end
end

