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
  "Gemfile" => "26b77e654971a51bdd6f68c9dfb069d390fbdad04f1267532d99fa6bbee106ad",
  "Gemfile.lock" => "2b43c8347b0333cd0f63ed21882c1c6a4f626edf65c4cbd1118da8a6c86a9d05",
  "package.json" => "884488b740a4e661712e19496c919c2256073517ad6c7f73baa5f17b018fc5c5",
  "aube-lock.yaml" => "eea740064b701146c07ac54822c4350062c5c6c556496e9baeee23e6640b8b42",
  "cli/go.mod" => "7fa082a96a652f0f16d2fef69e642a10b6bfad90e5f5c7401bd7ba6a7c48f6d0",
  "cli/go.sum" => "d545e881576b1331ef5dad5780a92b42c33968d425858981b7458f1741d6eb3e",
  "mise.lock" => "d6b7717c3f441f0e3bf2586e5d8e4c9de445601afcaacc890d808401e0873764",
  "mise.toml" => "e05cf214cfb368f8ec4e10221faac46541673477f756fca2176ec893e6d029ab"
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
  4dd00443 72a3effa 6385e90a 442f6b7f
  43eef317 420337e1 17545390 c957a79d
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
