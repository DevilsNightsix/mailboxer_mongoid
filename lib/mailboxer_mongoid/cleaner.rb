require 'singleton'

module MailboxerMongoid
  class Cleaner
    include Singleton
    include ActionView::Helpers::SanitizeHelper

  end
end
