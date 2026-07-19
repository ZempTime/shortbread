source "https://rubygems.org"

ruby "3.4.8"

gem "anycable-rails-core", "~> 1.6.2"
gem "aws-sdk-s3", "~> 1.226.0"
gem "bootsnap", "~> 1.24.6", require: false
gem "inertia_rails", "~> 3.21.2"
gem "pg", "~> 1.1"
gem "pitchfork", "~> 0.18.2"
gem "rails", "~> 8.1.3"
gem "solid_queue", "~> 1.4.0"
gem "vite_rails", "~> 3.11.0"
gem "webauthn", "~> 3.4.3"

gem "tzinfo-data", platforms: %i[jruby windows]

group :development, :test do
  gem "bundler-audit", "~> 0.9.3", require: false
  gem "debug", "~> 1.11.1", platforms: %i[mri windows], require: "debug/prelude"
  gem "rubocop-rails-omakase", "~> 1.1.0", require: false
end

group :development do
  gem "web-console", "~> 4.3.0"
end

group :test do
  gem "capybara", "~> 3.40.0"
  gem "minitest-mock", "~> 5.27.0"
  gem "puma", "~> 8.0.2"
  gem "selenium-webdriver", "~> 4.45.0"
end
