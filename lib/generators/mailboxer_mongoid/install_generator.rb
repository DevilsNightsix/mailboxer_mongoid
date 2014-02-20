class MailboxerMongoid::InstallGenerator < Rails::Generators::Base #:nodoc:
  include Rails::Generators::Migration
  source_root File.expand_path('../templates', __FILE__)

  def create_initializer_file
    template 'initializer.rb', 'config/initializers/mailboxer_mongoid.rb'
  end
end
