# frozen_string_literal: true

require "digest"
require "open3"
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
  "mise.lock" => "98ec06ddfbd67a83fe1bbc09e35db7c7377b567769d59c335ac7cfd60b827407",
  "mise.toml" => "6ca571722feeb327af42c691ad42313462277899d4c2b375ef00cdfd43462e77"
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
MISE_TELEMETRY_ENV = [
  'ANYCABLE_DISABLE_TELEMETRY = "true"',
  'TEST_TELEMETRY_DIR = "{{config_root}}/config/go-telemetry"'
].freeze

ANYCABLE_DEV_CONFIG_SHA256 = %w[
  4dd00443 72a3effa 6385e90a 442f6b7f
  43eef317 420337e1 17545390 c957a79d
].join.freeze
GO_TELEMETRY_MODE = ROOT.join("config/go-telemetry/mode")
POSTGRES_PLUGIN_REPOSITORY = "https://github.com/mise-plugins/mise-postgres.git"
POSTGRES_PLUGIN_REVISION = "dcbda94a5229b6906ecf87460584739d965d9ca0"
RUBY_BUILD_REVISION = "013c27d7e557b71b21bfa0f9c7af1081cf5411dc"

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

  source = path.read
  if relative_path == "mise.toml"
    MISE_TELEMETRY_ENV.each do |setting|
      unless source.scan(setting).one?
        abort "mise.toml must contain exactly one copy of every approved telemetry-disable setting"
      end
      source = source.sub(setting, "")
    end
  end

  matches = FORBIDDEN & identifiers(source)
  next if matches.empty?

  [ relative_path, matches ]
end

abort "Forbidden optional processor/proprietary dependencies: #{findings.inspect}" unless findings.empty?

anycable_config = ROOT.join("anycable.toml")
actual_anycable_digest = Digest::SHA256.file(anycable_config).hexdigest
unless actual_anycable_digest == ANYCABLE_DEV_CONFIG_SHA256
  abort "anycable.toml changed; review its fnox exception before updating the approved digest"
end

expected_telemetry_dir = GO_TELEMETRY_MODE.dirname.to_s
unless ENV["TEST_TELEMETRY_DIR"] == expected_telemetry_dir
  abort "Go telemetry isolation is inactive; enter through the checked-in mise environment"
end
unless ENV["ANYCABLE_DISABLE_TELEMETRY"] == "true"
  abort "AnyCable telemetry must remain disabled in the checked-in mise environment"
end
unless GO_TELEMETRY_MODE.read == "off\n"
  abort "Go telemetry isolation must remain fully off"
end
telemetry_files = GO_TELEMETRY_MODE.dirname.glob("**/*").select(&:file?)
unless telemetry_files == [ GO_TELEMETRY_MODE ]
  abort "Go created telemetry data inside the repository isolation directory"
end

data_home = if ENV["MISE_DATA_DIR"]
  Pathname.new(ENV.fetch("MISE_DATA_DIR"))
elsif ENV["XDG_DATA_HOME"]
  Pathname.new(ENV.fetch("XDG_DATA_HOME")).join("mise")
else
  Pathname.new(Dir.home).join(".local/share/mise")
end
postgres_plugin = data_home.join("plugins/postgres")
postgres_revision, _, revision_status = Open3.capture3(
  "git", "-C", postgres_plugin.to_s, "rev-parse", "HEAD"
)
postgres_origin, _, origin_status = Open3.capture3(
  "git", "-C", postgres_plugin.to_s, "remote", "get-url", "origin"
)
postgres_changes, _, changes_status = Open3.capture3(
  "git", "-C", postgres_plugin.to_s, "status", "--porcelain", "--untracked-files=all"
)
unless revision_status.success? && postgres_revision.strip == POSTGRES_PLUGIN_REVISION
  abort "Installed PostgreSQL plugin does not match the approved revision"
end
unless origin_status.success? && postgres_origin.strip == POSTGRES_PLUGIN_REPOSITORY
  abort "Installed PostgreSQL plugin does not match the approved repository"
end
unless changes_status.success? && postgres_changes.empty?
  abort "Installed PostgreSQL plugin contains unreviewed local changes"
end

mise_source = ROOT.join("mise.toml").read
unless mise_source.scan("#{POSTGRES_PLUGIN_REPOSITORY}##{POSTGRES_PLUGIN_REVISION}").one?
  abort "PostgreSQL installer source must remain pinned to the approved revision"
end
unless mise_source.scan("https://github.com/rbenv/ruby-build/archive/#{RUBY_BUILD_REVISION}.zip").one?
  abort "ruby-build must remain pinned to the approved revision archive"
end

puts "Dependency policy: approved frozen inventory exact; installer sources exact; denylisted identifiers absent; AnyCable dev exception exact; telemetry disabled"
