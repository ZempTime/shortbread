# frozen_string_literal: true

require "test_helper"
require_relative "walking_skeleton"

require "rbconfig"

class WalkingSkeletonContractTest < ActiveSupport::TestCase
  VALID_INVITATION = {
    ok: true,
    result: {
      resource: "invitation",
      id: 17,
      status: "created",
      link_written: true
    }
  }.freeze

  VALID_RELEASE_HISTORY = {
    ok: true,
    result: {
      resource: "release_history",
      site_slug: "walking-skeleton",
      current_release_number: 2,
      releases: [
        {
          id: 23,
          number: 2,
          manifest_sha256: "b" * 64,
          finalized_at: "2026-07-20T12:02:00.000000Z",
          current: true,
          files: 3,
          bytes: 431
        },
        {
          id: 19,
          number: 1,
          manifest_sha256: "a" * 64,
          finalized_at: "2026-07-20T12:01:00.000000Z",
          current: false,
          files: 3,
          bytes: 417
        }
      ],
      pagination: { limit: 50, next_before: nil }
    }
  }.freeze

  VALID_RELEASE_ROLLBACK = {
    ok: true,
    result: {
      resource: "release_rollback",
      status: "rolled_back",
      id: 29,
      site_slug: "walking-skeleton",
      from_release_number: 2,
      to_release_number: 1,
      resulting_release_number: 1,
      changed: true,
      recorded_at: "2026-07-20T12:03:00.000000Z"
    }
  }.freeze

  test "Invitation CLI output accepts only its exact redacted success schema" do
    with_cli(stdout: JSON.generate(VALID_INVITATION)) do |cli|
      assert_equal({ id: 17, link_written: true }, cli.call(:invitation, "invite", "create"))
    end

    %i[link locator token extra].each do |forbidden_key|
      payload = Marshal.load(Marshal.dump(VALID_INVITATION))
      payload.fetch(:result)[forbidden_key] = "synthetic-forbidden-marker"

      with_cli(stdout: JSON.generate(payload)) do |cli|
        assert_raises(ShortbreadBlackBox::Failure) { cli.call(:invitation, "invite", "create") }
      end
    end
  end

  test "CLI success rejects stderr and any envelope or status drift" do
    with_cli(stdout: JSON.generate(VALID_INVITATION), stderr: "synthetic-forbidden-marker") do |cli|
      assert_raises(ShortbreadBlackBox::Failure) { cli.call(:invitation, "invite", "create") }
    end

    extra_envelope = VALID_INVITATION.merge(extra: "synthetic-forbidden-marker")
    with_cli(stdout: JSON.generate(extra_envelope)) do |cli|
      assert_raises(ShortbreadBlackBox::Failure) { cli.call(:invitation, "invite", "create") }
    end

    wrong_status = Marshal.load(Marshal.dump(VALID_INVITATION))
    wrong_status.fetch(:result)[:status] = "unexpected"
    with_cli(stdout: JSON.generate(wrong_status)) do |cli|
      assert_raises(ShortbreadBlackBox::Failure) { cli.call(:invitation, "invite", "create") }
    end
  end

  test "publish CLI output accepts only the exact numeric Release summary" do
    payload = {
      ok: true,
      result: {
        resource: "release",
        id: 23,
        status: "published",
        number: 1,
        files: 1,
        uploaded: 1,
        reused: 0,
        bytes: 324
      }
    }

    with_cli(stdout: JSON.generate(payload)) do |cli|
      assert_equal(
        { id: 23, number: 1, files: 1, uploaded: 1, reused: 0, bytes: 324 },
        cli.call(:publish, "publish", "synthetic-bundle", "--site", "synthetic-site")
      )
    end
  end

  test "release history CLI output accepts only ordered immutable Release summaries" do
    with_cli(stdout: JSON.generate(VALID_RELEASE_HISTORY)) do |cli|
      result = cli.call(:release_history, "releases", "list", "--site", "walking-skeleton")

      assert_equal 2, result.fetch(:current_release_number)
      assert_equal [ 2, 1 ], result.fetch(:releases).map { |release| release.fetch("number") }
      assert_equal [ true, false ], result.fetch(:releases).map { |release| release.fetch("current") }
    end

    payload = Marshal.load(Marshal.dump(VALID_RELEASE_HISTORY))
    payload.fetch(:result).fetch(:releases).first[:private_path] = "synthetic-forbidden-marker"
    with_cli(stdout: JSON.generate(payload)) do |cli|
      assert_raises(ShortbreadBlackBox::Failure) do
        cli.call(:release_history, "releases", "list", "--site", "walking-skeleton")
      end
    end

    valid_max_slug = "a#{"-" * 61}z"
    payload = Marshal.load(Marshal.dump(VALID_RELEASE_HISTORY))
    payload.fetch(:result)[:site_slug] = valid_max_slug
    payload.fetch(:result).fetch(:releases).first[:bytes] = 0
    with_cli(stdout: JSON.generate(payload)) do |cli|
      result = cli.call(:release_history, "releases", "list", "--site", valid_max_slug)

      assert_equal valid_max_slug, result.fetch(:site_slug)
      assert_equal 0, result.fetch(:releases).first.fetch("bytes")
    end

    invalid_long_slug = "a#{"-" * 62}z"
    payload.fetch(:result)[:site_slug] = invalid_long_slug
    with_cli(stdout: JSON.generate(payload)) do |cli|
      assert_raises(ShortbreadBlackBox::Failure) do
        cli.call(:release_history, "releases", "list", "--site", invalid_long_slug)
      end
    end

    unpublished = Marshal.load(Marshal.dump(VALID_RELEASE_HISTORY))
    unpublished.fetch(:result)[:current_release_number] = nil
    unpublished.fetch(:result)[:releases] = []
    with_cli(stdout: JSON.generate(unpublished)) do |cli|
      result = cli.call(:release_history, "releases", "list", "--site", "walking-skeleton")

      assert_nil result.fetch(:current_release_number)
      assert_empty result.fetch(:releases)
    end

    older_page = Marshal.load(Marshal.dump(VALID_RELEASE_HISTORY))
    older_page.fetch(:result)[:releases] = [ older_page.fetch(:result).fetch(:releases).last ]
    with_cli(stdout: JSON.generate(older_page)) do |cli|
      result = cli.call(:release_history, "releases", "list", "--site", "walking-skeleton", "--before", "2")

      assert_equal 2, result.fetch(:current_release_number)
      assert_equal [ 1 ], result.fetch(:releases).map { |release| release.fetch("number") }
      assert_not result.fetch(:releases).first.fetch("current")
    end
  end

  test "release rollback CLI output accepts only its exact durable result" do
    with_cli(stdout: JSON.generate(VALID_RELEASE_ROLLBACK)) do |cli|
      assert_equal(
        {
          id: 29,
          site_slug: "walking-skeleton",
          from_release_number: 2,
          to_release_number: 1,
          resulting_release_number: 1,
          changed: true,
          recorded_at: "2026-07-20T12:03:00.000000Z"
        },
        cli.call(:release_rollback, "releases", "rollback", "--site", "walking-skeleton", "--release", "1")
      )
    end

    payload = Marshal.load(Marshal.dump(VALID_RELEASE_ROLLBACK))
    payload.fetch(:result)[:idempotency_key] = "synthetic-forbidden-marker"
    with_cli(stdout: JSON.generate(payload)) do |cli|
      assert_raises(ShortbreadBlackBox::Failure) do
        cli.call(:release_rollback, "releases", "rollback", "--site", "walking-skeleton", "--release", "1")
      end
    end


    no_op = Marshal.load(Marshal.dump(VALID_RELEASE_ROLLBACK))
    no_op.fetch(:result).merge!(
      status: "already_current",
      from_release_number: 1,
      changed: false
    )
    with_cli(stdout: JSON.generate(no_op)) do |cli|
      result = cli.call(:release_rollback, "releases", "rollback", "--site", "walking-skeleton", "--release", "1")

      assert_equal false, result.fetch(:changed)
      assert_equal result.fetch(:from_release_number), result.fetch(:to_release_number)
    end

    incoherent = Marshal.load(Marshal.dump(no_op))
    incoherent.fetch(:result)[:changed] = true
    with_cli(stdout: JSON.generate(incoherent)) do |cli|
      assert_raises(ShortbreadBlackBox::Failure) do
        cli.call(:release_rollback, "releases", "rollback", "--site", "walking-skeleton", "--release", "1")
      end
    end
  end

  test "temporary workspace uses the platform root and refuses unsafe removal" do
    workspace = ShortbreadBlackBox::TemporaryWorkspace.new
    root = workspace.root

    assert root.start_with?(File.realpath(Dir.tmpdir) + File::SEPARATOR)
    assert_equal 0o700, File.stat(root).mode & 0o777
    Socket.pack_sockaddr_un(File.join(root, ".s.PGSQL.55432"))

    assert_not workspace.cleanup(processes_stopped: false)
    assert Dir.exist?(root)
    assert workspace.cleanup(processes_stopped: true)
    assert_not File.exist?(root)
  ensure
    FileUtils.remove_entry_secure(root) if root && File.exist?(root)
  end

  test "bounded process termination escalates and reaps a resistant child" do
    reader, writer = IO.pipe
    child = <<~'RUBY'
      trap("TERM") {}
      STDOUT.write("ready")
      STDOUT.flush
      sleep 60
    RUBY
    pid = Process.spawn(
      RbConfig.ruby, "-e", child,
      out: writer,
      err: File::NULL,
      pgroup: true
    )
    writer.close
    assert_equal "ready", reader.read(5)
    terminator = ShortbreadBlackBox::ProcessTerminator.new(
      pid:,
      pgid: pid,
      term_timeout: 0.05,
      kill_timeout: 1
    )

    assert terminator.stop
    assert_not terminator.alive?
    assert_raises(Errno::ECHILD) { Process.waitpid(pid, Process::WNOHANG) }
  ensure
    reader&.close
    writer&.close unless writer&.closed?
    begin
      Process.kill("KILL", -pid) if pid
    rescue Errno::ESRCH
      nil
    end
    begin
      Process.wait(pid) if pid
    rescue Errno::ECHILD
      nil
    end
  end

  private

  def with_cli(stdout:, stderr: "", status: 0)
    Dir.mktmpdir("sb-cli-contract-", Dir.tmpdir) do |root|
      executable = File.join(root, "synthetic-cli")
      File.write(executable, <<~'RUBY', mode: "wb", perm: 0o700)
        #!/usr/bin/env ruby
        STDOUT.write(ENV.fetch("SYNTHETIC_CLI_STDOUT"))
        STDERR.write(ENV.fetch("SYNTHETIC_CLI_STDERR"))
        exit Integer(ENV.fetch("SYNTHETIC_CLI_STATUS"))
      RUBY
      cli = ShortbreadBlackBox::CliRunner.new(
        executable:,
        server_origin: "http://shortbread.localhost:3000",
        token: "synthetic-test-token",
        chdir: root,
        environment: {
          "SYNTHETIC_CLI_STDOUT" => stdout,
          "SYNTHETIC_CLI_STDERR" => stderr,
          "SYNTHETIC_CLI_STATUS" => status.to_s
        }
      )
      yield cli
    ensure
      cli&.clear
    end
  end
end
