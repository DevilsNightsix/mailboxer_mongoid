class Mailboxer::NamespacingCompatibilityGenerator < Rails::Generators::Base
  include Rails::Generators::Migration
  source_root File.expand_path('../templates', __FILE__)
  require 'rails/generators/migration'

  FILENAME = 'mailboxer_namespacing_compatibility.rb'

  source_root File.expand_path('../templates', __FILE__)


end
