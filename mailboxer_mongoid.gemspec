Gem::Specification.new do |s|
  s.name = "mailboxer_mongoid"
  s.version = "0.01.0"

  s.authors = ["Eduardo Casanova Cuesta", "Peter Kirby"]
  s.summary = "Messaging system for rails apps."
  s.description = "This is a version of Mailboxer rebuilt specifically to support mongoid. It has not been thoroughly tested" +
                  " and is likely not optimized. Use at your own risk. Mailboxer-mongoid is being developed by Peter kirby" +
                  "Check out https://github.com/ging/mailboxer_mongoid to learn about the original." +
                  "A Rails engine that allows any model to act as messageable, adding the ability to exchange messages " +
                   "with any other messageable model, even different ones. It supports the use of conversations with " +
                   "two or more recipients to organize the messages. You have a complete use of a mailbox object for " +
                   "each messageable model that manages an inbox, sentbox and trash for conversations. It also supports " +
                   "sending notifications to messageable models, intended to be used as system notifications."
  s.email = "peterjkirby@live.com"
  s.homepage = "https://github.com/peterjkirby/mailboxer_mongoid-mongoid"
  s.files = `git ls-files`.split("\n")
  s.license = 'MIT'

  # Gem dependencies
  #

  # Development Gem dependencies
  s.add_runtime_dependency('rails', '>= 3.0.0')
  s.add_runtime_dependency('carrierwave', '>= 0.5.8')


  # Debugging
  if RUBY_VERSION < '1.9'
    s.add_development_dependency('ruby-debug', '>= 0.10.3')
  end

  if RUBY_ENGINE == "rbx" && RUBY_VERSION >= "2.1.0"
    # Rubinius has it's own dependencies
    s.add_runtime_dependency     'rubysl-singleton'
    s.add_development_dependency 'rubysl-test-unit'
    s.add_development_dependency 'racc'
  end

  # Specs
  s.add_development_dependency('rspec-rails', '>= 2.6.1')
  s.add_development_dependency('mongoid-rspec')
  s.add_development_dependency('database_cleaner')
  s.add_development_dependency("appraisal")

  # Fixtures
  if RUBY_VERSION >= '1.9.2'
    s.add_development_dependency('factory_girl', '>= 3.0.0')
  else
    s.add_development_dependency('factory_girl', '~> 2.6.0')
  end

  # Integration testing
  #s.add_development_dependency('capybara')

  # Database
  s.add_dependency("mongoid", ">= 3.0.0")
  s.add_dependency("bson_ext")


end
