# frozen_string_literal: true

require "bundler"
require "json"
require "open3"
require "pathname"
require "yaml"

ROOT = Pathname.new(__dir__).join("..").expand_path
POLICY = YAML.safe_load_file(ROOT.join("config/dependency-licenses.yml"), aliases: false)

def capture!(*command, chdir: ROOT)
  stdout, stderr, status = Open3.capture3(*command, chdir: chdir.to_s)
  abort stderr unless status.success?

  stdout
end

def assert_allowed!(ecosystem, package, licenses)
  allowed = POLICY.fetch("allowed").fetch(ecosystem)
  invalid = licenses - allowed
  abort "#{ecosystem} license policy rejected #{package}: #{invalid.join(', ')}" unless invalid.empty?
end

lock = Bundler::LockfileParser.new(Bundler.read_file(ROOT.join("Gemfile.lock")))
abort "Ruby lockfile has no CHECKSUMS section" unless lock.checksums

missing_ruby_checksums = lock.specs.select { |spec| spec.source.checksum_store.missing?(spec) }
unless missing_ruby_checksums.empty?
  abort "Ruby lockfile lacks checksums for: #{missing_ruby_checksums.map(&:full_name).join(', ')}"
end

locked_ruby = lock.specs.group_by(&:name).transform_values { |specs| specs.map { |spec| spec.version.to_s }.uniq }
host_ruby = Bundler.load.specs.group_by(&:name)
ruby_lock_only = POLICY.fetch("ruby_lock_only")

locked_ruby.each do |name, versions|
  abort "Ruby lock contains multiple versions for #{name}: #{versions.join(', ')}" unless versions.one?

  audited = ruby_lock_only[name]
  if audited
    abort "Ruby platform-only version changed: #{name} #{versions.first}" unless audited.fetch("version") == versions.first
  end

  host_spec = host_ruby.fetch(name, []).find { |spec| spec.version.to_s == versions.first }
  if host_spec
    licenses = host_spec.licenses
    abort "Ruby gem #{name} #{versions.first} has no declared license" if licenses.empty?

    if audited && licenses.sort != audited.fetch("licenses").sort
      abort "Ruby platform-only license metadata changed: #{name} #{versions.first}"
    end
  else
    audited ||= ruby_lock_only.fetch(name) { abort "Ruby platform-only gem lacks policy: #{name} #{versions.first}" }
    licenses = audited.fetch("licenses")
  end

  assert_allowed!("ruby", "#{name} #{versions.first}", licenses)
end

unused_ruby_exceptions = ruby_lock_only.keys - locked_ruby.keys
abort "Stale Ruby platform-only policy: #{unused_ruby_exceptions.join(', ')}" unless unused_ruby_exceptions.empty?

browser = JSON.parse(capture!("aube", "licenses", "--json"))
browser_unknown = POLICY.fetch("browser_unknown")
unknown_count = 0
matched_browser_rules = []

browser.each do |package|
  matches = browser_unknown.select do |rule|
    Regexp.new(rule.fetch("pattern")).match?(package.fetch("name")) && rule.fetch("version") == package.fetch("version")
  end
  abort "Ambiguous browser license policy: #{package.fetch('name')} #{package.fetch('version')}" if matches.length > 1
  matched_browser_rules.concat(matches)

  if package.fetch("license") == "UNKNOWN"
    unknown_count += 1
    abort "Unclassified browser license: #{package.fetch('name')} #{package.fetch('version')}" unless matches.one?
    assert_allowed!(
      "browser",
      "#{package.fetch('name')} #{package.fetch('version')}",
      [ matches.first.fetch("license") ],
    )
  else
    assert_allowed!(
      "browser",
      "#{package.fetch('name')} #{package.fetch('version')}",
      [ package.fetch("license") ],
    )

    if matches.one? && matches.first.fetch("license") != package.fetch("license")
      abort "Browser license metadata changed: #{package.fetch('name')} #{package.fetch('version')}"
    end
  end
end

unused_browser_rules = browser_unknown - matched_browser_rules
abort "Stale browser UNKNOWN policy: #{unused_browser_rules.map { |rule| rule.fetch('pattern') }.join(', ')}" unless unused_browser_rules.empty?

go_modules = capture!("go", "list", "-mod=readonly", "-m", "-f", "{{if not .Main}}{{.Path}}\t{{.Version}}{{end}}", "all", chdir: ROOT.join("cli"))
  .lines
  .filter_map { |line| line.strip.split("\t", 2) unless line.strip.empty? }
  .to_h
go_policy = POLICY.fetch("go")

abort "Unclassified Go modules: #{(go_modules.keys - go_policy.keys).join(', ')}" unless (go_modules.keys - go_policy.keys).empty?
abort "Stale Go license policy: #{(go_policy.keys - go_modules.keys).join(', ')}" unless (go_policy.keys - go_modules.keys).empty?

go_modules.each do |name, version|
  audited = go_policy.fetch(name)
  abort "Go module version changed: #{name} #{version}" unless audited.fetch("version") == version

  assert_allowed!("go", "#{name} #{version}", [ audited.fetch("license") ])
end

puts "License audit: #{locked_ruby.size} Ruby gems; #{browser.size} browser packages (#{unknown_count} exact/pattern-bounded native/WASM metadata exceptions); #{go_modules.size} Go modules"
