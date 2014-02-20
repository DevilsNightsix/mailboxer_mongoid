require 'carrierwave'
#begin
#  require 'sunspot_rails'
#rescue LoadError
# end

module MailboxerMongoid

  class Engine < Rails::Engine
    initializer "mailboxer_mongoid.models.messageable" do
      ActiveSupport.on_load(:mongoid) do
        Mongoid::Document::ClassMethods.send :include, MailboxerMongoid::Models::Messageable::MongoidExtension
        #Mongoid::Factory::ClassMethods.send :include, MailboxerMongoid::MongoidExt::Factory
        Mongoid::Factory.send :extend, MailboxerMongoid::MongoidExt::Factory

      end

    end

  end

end
