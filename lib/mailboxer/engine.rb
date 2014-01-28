require 'carrierwave'
#begin
#  require 'sunspot_rails'
#rescue LoadError
# end

module Mailboxer

  class Engine < Rails::Engine
    initializer "mailboxer.models.messageable" do
      ActiveSupport.on_load(:mongoid) do
        Mongoid::Document::ClassMethods.send :include, Mailboxer::Models::Messageable::MongoidExtension
      end

    end

  end

end
