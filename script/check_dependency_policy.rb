# frozen_string_literal: true

require "digest"
require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
MANIFESTS = %w[
  Gemfile
  Gemfile.lock
  package.json
  aube-lock.yaml
  cli/go.mod
  cli/go.sum
  mise.lock
  mise.toml
].freeze
APPROVED_SHA256 = {
  "Gemfile" => "f4db58a991234c2901420c60d1a1d986fcbf936e6713b194a5bbd48599b09e41",
  "Gemfile.lock" => "d88c5c3d7bc6efde2b1bbb75548210de9765af44fc1a2f3376e3934067edff5b",
  "package.json" => "faf29c611ac72340ab5858118dbaa630a084b7e9623e130f059904214393e070",
  "aube-lock.yaml" => "9c44ce59c8f03c92e40332b40e364ad9752faa8a3ee73d31e2760ff1f021edda",
  "cli/go.mod" => "7fa082a96a652f0f16d2fef69e642a10b6bfad90e5f5c7401bd7ba6a7c48f6d0",
  "cli/go.sum" => "d545e881576b1331ef5dad5780a92b42c33968d425858981b7458f1741d6eb3e",
  "mise.lock" => "4d898ab54f627469d2f2f406fb7d236dce3ce6a11bf085b8f85515f04038de31",
  "mise.toml" => "ae476e65241d3affc15c6812b567c66732d07393d743fd30156f66db0872ae6c"
}.freeze
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
  opentelemetry
  openai
  posthog
  rollbar
  segment
  sentry
  skylight
  telemetry
].freeze

ANYCABLE_DEV_CONFIG_SHA256 = %w[
  91aef562 7893401e 75d78515 2f9b6800
  c50c4672 382d93aa 94f78878 6930cbf6
].join.freeze

def identifiers(source)
  source.downcase.scan(/[a-z0-9]+/)
end

matcher_probes = {
  "newrelic_rpm" => "newrelic",
  "@opentelemetry/api" => "opentelemetry",
  "vendor-telemetry-agent" => "telemetry"
}
matcher_probes.each do |source, expected|
  abort "Dependency policy matcher failed its #{source} probe" unless identifiers(source).include?(expected)
end

findings = MANIFESTS.filter_map do |relative_path|
  path = ROOT.join(relative_path)
  abort "Missing governed dependency manifest: #{relative_path}" unless path.file?

  actual_digest = Digest::SHA256.file(path).hexdigest
  unless actual_digest == APPROVED_SHA256.fetch(relative_path)
    abort "Dependency inventory changed without controller review: #{relative_path}"
  end

  matches = FORBIDDEN & identifiers(path.read)
  next if matches.empty?

  [ relative_path, matches ]
end

abort "Forbidden optional processor/proprietary dependencies: #{findings.inspect}" unless findings.empty?

anycable_config = ROOT.join("anycable.toml")
actual_anycable_digest = Digest::SHA256.file(anycable_config).hexdigest
unless actual_anycable_digest == ANYCABLE_DEV_CONFIG_SHA256
  abort "anycable.toml changed; review its fnox exception before updating the approved digest"
end

puts "Dependency policy: approved frozen inventory exact; denylisted identifiers absent; AnyCable dev exception exact"
