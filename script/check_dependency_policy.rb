# frozen_string_literal: true

require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
MANIFESTS = %w[
  Gemfile
  Gemfile.lock
  package.json
  aube-lock.yaml
  cli/go.mod
  cli/go.sum
].freeze
FORBIDDEN = %w[
  airbrake
  amplitude
  anthropic
  brakeman
  bugsnag
  datadog
  honeybadger
  langchain
  mixpanel
  newrelic
  openai
  posthog
  rollbar
  segment
  sentry
  skylight
].freeze

findings = MANIFESTS.filter_map do |relative_path|
  path = ROOT.join(relative_path)
  next unless path.file?

  normalized = path.read.downcase
  matches = FORBIDDEN.select { |name| normalized.match?(/\b#{Regexp.escape(name)}\b/) }
  [relative_path, matches] unless matches.empty?
end

abort "Forbidden optional processor/proprietary dependencies: #{findings.inspect}" unless findings.empty?

puts "Dependency policy: no telemetry, AI, proprietary-service, or omitted Brakeman packages"
