# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "open3"
require "pathname"
require "rbconfig"
require "tmpdir"

class SecretScanTest < Minitest::Test
  ROOT = Pathname.new(__dir__).join("../..").expand_path
  SCRIPT = ROOT.join("script/check_secret_scan.rb")
  FNOX_ARGUMENTS = [
    "--config", "fnox.toml", "--non-interactive", "scan", "--format", "json",
    "--ignore", ".git/**", "--ignore", "tmp/**", "--ignore", "node_modules/**",
    "--ignore", "anycable.toml", "."
  ].freeze

  def test_allows_a_dynamic_assignment_before_an_unrelated_literal
    source = 'accepted = flow(token: acceptance.token, audience: "unrelated literal") # SYNTHETIC_MARKER'

    with_repository("app/flow.rb" => "#{source}\n") do |root|
      finding = finding_for("app/flow.rb", source, "acceptance.token")
      stdout, stderr, status = run_scan(root, findings: [ finding ], scanner_status: 1)

      assert status.success?, stderr
      assert_equal "Secret scan passed.\n", stdout
      assert_empty stderr
    end
  end

  def test_allows_only_explicit_synthetic_literals_in_test_files
    ruby_source = 'token = "sYnThEtIc-token"'
    go_source = 'token: "TOKEN_marker", other: dynamicValue'
    files = {
      "test/client_test.rb" => "#{ruby_source}\n",
      "cli/client_test.go" => "#{go_source}\n"
    }

    with_repository(files) do |root|
      findings = [
        finding_for("test/client_test.rb", ruby_source, '"sYnThEtIc-token"'),
        finding_for("cli/client_test.go", go_source, '"TOKEN_marker"')
      ]
      stdout, stderr, status = run_scan(root, findings: findings, scanner_status: 1)

      assert status.success?, stderr
      assert_equal "Secret scan passed.\n", stdout
      assert_empty stderr
    end
  end

  def test_rejects_hard_coded_assignments_in_production_and_tests
    cases = {
      "production synthetic marker" => [ "app/client.rb", 'token = "SYNTHETIC_PRODUCTION_MARKER"' ],
      "test non-synthetic literal" => [ "test/client_test.rb", non_synthetic_assignment ]
    }

    cases.each do |name, (path, source)|
      with_repository(path => "#{source}\n") do |root|
        finding = finding_for(path, source, source.split("=", 2).last.strip)
        stdout, stderr, status = run_scan(root, findings: [ finding ], scanner_status: 1)

        refute status.success?, name
        assert_equal "", stdout, name
        assert_equal "Secret scan failed.\n", stderr, name
        refute_includes stdout + stderr, source, name
        refute_includes stdout + stderr, path, name
        refute_includes stdout + stderr, "PRIVATE_REDACTED_MARKER", name
      end
    end
  end

  def test_synthetic_test_exception_is_scoped_to_the_reported_value
    flagged_assignment = non_synthetic_assignment
    source = %(#{flagged_assignment}; note = "SYNTHETIC_MARKER")
    flagged_value = flagged_assignment.split("=", 2).last.strip

    with_repository("test/client_test.rb" => "#{source}\n") do |root|
      finding = finding_for("test/client_test.rb", source, flagged_value)
      stdout, stderr, status = run_scan(root, findings: [ finding ], scanner_status: 1)

      refute status.success?
      assert_equal "", stdout
      assert_equal "Secret scan failed.\n", stderr
      refute_includes stdout + stderr, source
    end
  end

  def test_rejects_a_clean_scan_that_inspected_zero_files
    payload = {
      "findings" => [],
      "summary" => { "files_scanned" => 0, "files_with_findings" => 0, "findings" => 0 }
    }

    with_repository("app/client.rb" => "dynamic = value\n") do |root|
      stdout, stderr, status = run_scan(
        root,
        findings: [],
        scanner_status: 0,
        scanner_stdout: JSON.generate(payload)
      )

      refute status.success?
      assert_equal "", stdout
      assert_equal "Secret scan failed.\n", stderr
    end
  end

  def test_rejects_every_other_detector_even_for_a_dynamic_assignment
    source = "token = acceptance.token # SYNTHETIC_MARKER"

    with_repository("app/client.rb" => "#{source}\n") do |root|
      finding = finding_for("app/client.rb", source, "acceptance.token", detector: "aws-access-key")
      stdout, stderr, status = run_scan(root, findings: [ finding ], scanner_status: 1)

      refute status.success?
      assert_equal "", stdout
      assert_equal "Secret scan failed.\n", stderr
    end
  end

  def test_malformed_json_paths_lines_and_assignment_segments_fail_closed
    source = "token = acceptance.token # SYNTHETIC_MARKER"

    with_repository("app/client.rb" => "#{source}\n") do |root|
      valid = finding_for("app/client.rb", source, "acceptance.token")
      cases = {
        "malformed JSON" => { scanner_stdout: "PRIVATE_JSON_MARKER{" },
        "traversal path" => { findings: [ valid.merge("path" => "../PRIVATE_PATH_MARKER.rb") ] },
        "missing line" => { findings: [ valid.merge("line" => 2) ] },
        "invalid column" => { findings: [ valid.merge("column" => source.bytesize + 1) ] },
        "ambiguous assignment" => {
          files: { "app/client.rb" => "token = fetch(value\n" },
          findings: [ finding_for("app/client.rb", "token = fetch(value", "fetch(value") ]
        }
      }

      cases.each do |name, options|
        files = options.fetch(:files, {})
        files.each { |path, contents| root.join(path).write(contents) }
        stdout, stderr, status = run_scan(
          root,
          findings: options.fetch(:findings, [ valid ]),
          scanner_status: 1,
          scanner_stdout: options[:scanner_stdout]
        )

        refute status.success?, name
        assert_equal "", stdout, name
        assert_equal "Secret scan failed.\n", stderr, name
        refute_includes stdout + stderr, "PRIVATE_", name
      ensure
        root.join("app/client.rb").write("#{source}\n")
      end
    end
  end

  def test_scanner_operational_errors_are_redacted
    source = "token = acceptance.token # SYNTHETIC_MARKER"

    with_repository("app/client.rb" => "#{source}\n") do |root|
      finding = finding_for("app/client.rb", source, "acceptance.token")
      stdout, stderr, status = run_scan(
        root,
        findings: [ finding ],
        scanner_status: 2,
        scanner_stderr: "PRIVATE_TOOL_ERROR_MARKER"
      )

      refute status.success?
      assert_equal "", stdout
      assert_equal "Secret scan failed.\n", stderr
      refute_includes stdout + stderr, "PRIVATE_TOOL_ERROR_MARKER"
    end
  end

  private

  def with_repository(files)
    Dir.mktmpdir("shortbread-secret-scan-test") do |directory|
      root = Pathname.new(directory)
      files.each do |relative_path, source|
        path = root.join(relative_path)
        path.dirname.mkpath
        path.write(source)
      end
      yield root
    end
  end

  def finding_for(path, source, value, detector: "secret-assignment")
    {
      "path" => path,
      "line" => 1,
      "column" => source.index(value) + 1,
      "detector" => detector,
      "severity" => "medium",
      "redacted" => "PRIVATE_REDACTED_MARKER"
    }
  end

  def non_synthetic_assignment
    key = %w[to ken].join
    value = %w[private credential].join("-")
    [ key, " = ", 34.chr, value, 34.chr ].join
  end

  def run_scan(root, findings:, scanner_status:, scanner_stderr: "", scanner_stdout: nil)
    Dir.mktmpdir("shortbread-fake-fnox") do |directory|
      fake_bin = Pathname.new(directory)
      scanner = fake_bin.join("fnox")
      scanner.write(<<~RUBY)
        #!/usr/bin/env ruby
        require "json"
        unless ARGV == JSON.parse(ENV.fetch("FNOX_FAKE_EXPECTED_ARGUMENTS"))
          warn "FAKE_ARGUMENT_MISMATCH_MARKER"
          exit 2
        end
        STDOUT.write(ENV.fetch("FNOX_FAKE_STDOUT"))
        STDERR.write(ENV.fetch("FNOX_FAKE_STDERR"))
        exit Integer(ENV.fetch("FNOX_FAKE_STATUS"))
      RUBY
      scanner.chmod(0o700)
      payload = {
        "findings" => findings,
        "summary" => {
          "files_scanned" => [ findings.length, 1 ].max,
          "files_with_findings" => findings.map { |finding| finding.fetch("path") }.uniq.length,
          "findings" => findings.length
        }
      }
      environment = {
        "PATH" => "#{fake_bin}#{File::PATH_SEPARATOR}#{ENV.fetch("PATH")}",
        "FNOX_FAKE_EXPECTED_ARGUMENTS" => JSON.generate(FNOX_ARGUMENTS),
        "FNOX_FAKE_STDOUT" => scanner_stdout || JSON.generate(payload),
        "FNOX_FAKE_STDERR" => scanner_stderr,
        "FNOX_FAKE_STATUS" => scanner_status.to_s
      }
      Open3.capture3(environment, RbConfig.ruby, SCRIPT.to_s, root.to_s)
    end
  end
end
