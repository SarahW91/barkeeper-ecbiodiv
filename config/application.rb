# frozen_string_literal: true

require_relative 'boot'

require 'csv'
require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module GBOLapp
  class Application < Rails::Application
    config.generators do |g|
      g.test_framework :minitest
    end

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    config.cache_store = :redis_store,
        "redis://#{ENV.fetch('REDIS_HOST', 'localhost')}:6379/0/cache",
        { expires_in: 90.minutes }

    config.assets.paths << "#{Rails}/app/assets/fonts"
    config.assets.paths << "#{Rails}/vendor/assets/fonts"

    # config.assets.enabled = true
    # config.assets.precompile += %w(*.png *.jpg *.jpeg *.gif)

    config.autoload_paths << "#{Rails.root}/lib"
    config.eager_load_paths << "#{Rails.root}/lib"

    logger           = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.log_tags  = [:subdomain, :uuid]
    config.logger    = ActiveSupport::TaggedLogging.new(logger)
  end
end
