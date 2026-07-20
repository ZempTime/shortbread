require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
# require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

require_relative "../lib/shortbread/rack_responses"
require_relative "../lib/shortbread/hosts"
require_relative "../lib/shortbread/host_identity"
require_relative "../lib/shortbread/host_identity_guard"
require_relative "../lib/shortbread/host_scoped_static"
require_relative "../lib/shortbread/host_scoped_vite_proxy"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Shortbread
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    config.hosts = [ Shortbread::Hosts.authorization_pattern ]
    config.host_authorization = {
      response_app: ->(_environment) { Shortbread::RackResponses.not_found }
    }
    config.middleware.insert_before 0, Shortbread::HostIdentityGuard
    config.middleware.swap ActionDispatch::Static, Shortbread::HostScopedStatic

    initializer "shortbread.host_scoped_vite_proxy", after: "vite_rails.proxy" do |application|
      if ViteRuby.run_proxy?
        application.middleware.swap(
          ViteRuby::DevServerProxy,
          Shortbread::HostScopedViteProxy,
          ssl_verify_none: true
        )
      end
    end

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
