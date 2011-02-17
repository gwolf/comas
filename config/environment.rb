# Be sure to restart your server when you modify this file

# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '2.3.5' unless defined? RAILS_GEM_VERSION

# Some modules require to be loaded before Rails is initialized in
# order for the production environment not to break
require 'gettext'
require 'prawn'
require 'prawn/measurement_extensions'
require 'lib/pdf_dimensions'

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

Rails::Initializer.run do |config|
  # Settings in config/environments/* take precedence over those specified here.
  # Application configuration should go into files in config/initializers
  # -- all .rb files in that directory are automatically loaded.

  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/extras )

  # Specify gems that this application depends on and have them installed with rake gems:install
  # config.gem "bj"
  # config.gem "hpricot", :version => '0.6', :source => "http://code.whytheluckystiff.net"
  # config.gem "sqlite3-ruby", :lib => "sqlite3"
  # config.gem "aws-s3", :lib => "aws/s3"

  # Only load the plugins named here, in the order given (default is alphabetical).
  # :all can be used as a placeholder for all plugins not explicitly named
  # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

  # Skip frameworks you're not going to use. To use Rails without a database,
  # you must remove the Active Record framework.
  # config.frameworks -= [ :active_record, :active_resource, :action_mailer ]

  # Use the database for sessions instead of the file system
  # (create the session table with 'rake db:sessions:create')
  config.action_controller.session_store = :active_record_store
  config.action_controller.session = { 
    :session_key => "_comas_session_id", 
    :secret => "9ffb62fa7055a3f4009b824be282fc38" }


  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

  # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
  # Run "rake -D time" for a list of tasks for finding time zone names.
  config.time_zone = 'UTC'

  # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
  # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}')]
  # config.i18n.default_locale = :de
end

# Add new mime types for use in respond_to blocks:
# Mime::Type.register "text/richtext", :rtf
# Mime::Type.register "application/x-mobile", :mobile

# Mail configurations should be set in config/mail_settings - If it
# does not exist, mail will just not be sent (they will be handled as
# if testing)
begin
  require('config/mail_settings') 
rescue MissingSourceFile
  warn "*** Mail configuration not set"
  warn "Please create config/mail_settings.rb with your mail configuration. "
  warn "You can base your configuration off the template mail_settings.rb.orig"
  warn ""
  warn "The most basic configuration file, indicating no mail should be sent,"
  warn "would be:"
  warn ""
  warn "ActionMailer::Base.perform_deliveries = false"
  warn ""
  warn "Please create config/mail_settings.rb and try again."
  exit 2
end

# Include your application configuration below
require 'locale'
require 'locale_rails'
require 'gettext_activerecord'
require 'gettext_rails'
require 'classinherit'
require 'barby'
require 'barby/outputter/prawn_outputter'
require 'pseudo_gettext'
require 'redcloth'
require 'RMagick'
require 'simplexls'
require 'strings_with_random'
require 'will_paginate'
