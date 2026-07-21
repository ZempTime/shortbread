# frozen_string_literal: true

require "test_helper"

require "open3"
require "rbconfig"
require "tmpdir"

class ProductionRuntimeSmokeTest < ActiveSupport::TestCase
  test "an unexpected contradictory configuration failure never emits generated secrets" do
    generated_secret = "ab" * 32

    Dir.mktmpdir("shortbread-smoke-fakes") do |directory|
      write_executable(File.join(directory, "openssl"), <<~RUBY)
        #!/usr/bin/env ruby
        puts #{generated_secret.inspect}
      RUBY
      write_executable(File.join(directory, "docker"), <<~'RUBY')
        #!/usr/bin/env ruby
        if ARGV.first == "compose"
          exit 0
        elsif ARGV.first == "build"
          exit 0
        elsif ARGV.first(2) == %w[image inspect]
          puts "10001:10001"
          exit 0
        elsif ARGV.first == "run" && !ARGV.include?("--env-file")
          warn "production configuration error: missing production configuration"
          exit 78
        elsif ARGV.first == "run"
          environment_file = ARGV.fetch(ARGV.index("--env-file") + 1)
          environment = File.readlines(environment_file, chomp: true).to_h do |line|
            line.split("=", 2)
          end
          warn [
            "simulated contradictory configuration",
            environment.fetch("SHORTBREAD_BOOTSTRAP_TOKEN"),
            environment.fetch("SHORTBREAD_POSTGRES_PASSWORD"),
            environment.fetch("SECRET_KEY_BASE"),
            environment.fetch("ANYCABLE_SECRET"),
            environment.fetch("DATABASE_URL"),
            environment.fetch("QUEUE_DATABASE_URL")
          ].join(" ")
          exit 1
        end

        warn "unexpected fake Docker invocation"
        exit 2
      RUBY

      stdout, stderr, status = Open3.capture3(
        { "PATH" => "#{directory}:#{ENV.fetch('PATH')}" },
        Rails.root.join("bin/production-smoke").to_s,
        chdir: Rails.root.to_s
      )

      assert_equal 1, status.exitstatus
      assert_includes stderr, "contradictory configuration did not fail closed"
      assert_equal false, [ stdout, stderr ].any? { |output| output.include?(generated_secret) },
        "a generated secret reached smoke output"
    end
  end

  test "one non-root candidate image boots every production process and its local dependencies" do
    skip "set SHORTBREAD_RUN_CONTAINER_SMOKE=1 to exercise the container runtime" unless
      ENV["SHORTBREAD_RUN_CONTAINER_SMOKE"] == "1"

    stdout, stderr, status = Open3.capture3(
      Rails.root.join("bin/production-smoke").to_s,
      chdir: Rails.root.to_s
    )

    assert status.success?, <<~MESSAGE
      production runtime smoke failed
      stdout:
      #{stdout}
      stderr:
      #{stderr}
    MESSAGE
    assert_includes stdout, "HTTPS proxy/API Site creation: green"
    assert_includes stdout, "production runtime smoke: green"
  end


  private

  def write_executable(path, contents)
    File.write(path, contents)
    File.chmod(0o700, path)
  end
end
