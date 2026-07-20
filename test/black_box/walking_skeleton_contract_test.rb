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
