module MailboxerMongoid
  module Models
    autoload :Messageable, 'mailboxer_mongoid/models/messageable'
  end

  module MongoidExt
    autoload :Factory, 'mailboxer_mongoid/mongoid_ext/factory'
  end

  mattr_accessor :default_from
  @@default_from = "no-reply@mailboxer_mongoid.com"
  mattr_accessor :uses_emails
  @@uses_emails = true
  mattr_accessor :mailer_wants_array
  @@mailer_wants_array = false
  mattr_accessor :search_enabled
  @@search_enabled = false
  mattr_accessor :search_engine
  @@search_engine = :solr
  mattr_accessor :email_method
  @@email_method = :mailboxer_email
  mattr_accessor :name_method
  @@name_method = :name
  mattr_accessor :notification_mailer
  mattr_accessor :message_mailer
  mattr_accessor :custom_deliver_proc

  class << self
    def setup
      yield self
    end

    def protected_attributes?
      Rails.version < '4' || defined?(ProtectedAttributes)
    end
  end

end
# reopen ActiveRecord and include all the above to make
# them available to all our models if they want it
require 'mailboxer_mongoid/engine'
require 'mailboxer_mongoid/cleaner'
require 'mailboxer_mongoid/mail_dispatcher'
