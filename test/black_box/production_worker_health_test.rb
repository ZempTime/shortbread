# frozen_string_literal: true

require "test_helper"

require "json"
require "open3"
require "pg"
require "socket"
require "tmpdir"
require "time"
require "uri"

class ProductionWorkerHealthTest < ActiveSupport::TestCase
  VALID_ENVIRONMENT = {
    "ANYCABLE_HTTP_BROADCAST_URL" => "http://cable:8090/_broadcast",
    "ANYCABLE_RPC_HOST" => "http://shortbread.internal:3000/_anycable",
    "ANYCABLE_SECRET" => "a" * 64,
    "ANYCABLE_WEBSOCKET_URL" => "wss://shortbread.example/cable",
    "RAILS_ENV" => "production",
    "SECRET_KEY_BASE" => "b" * 64,
    "SHORTBREAD_APEX_HOST" => "shortbread.example",
    "SHORTBREAD_BLOB_ROOT" => "/var/lib/shortbread/blobs",
    "SHORTBREAD_BOOTSTRAP_TOKEN" => "c" * 64
  }.freeze

  teardown do
    @queue_connection&.close
  end

  test "worker health rejects an unrelated fresh registration without a current role start" do
    decoy_id = register_process(kind: "Worker", hostname: Socket.gethostname)

    Dir.mktmpdir("shortbread-worker-health") do |directory|
      _, stderr, status = run_worker_health(File.join(directory, "missing-start.json"))

      refute status.success?
      assert_equal "worker health failed\n", stderr
    end
  ensure
    delete_process(decoy_id) if decoy_id
  end

  test "worker health rejects a stale same-host registration with a recent heartbeat" do
    stale_worker_id = register_process(
      kind: "Worker",
      hostname: Socket.gethostname,
      created_at: 10.minutes.ago
    )

    Dir.mktmpdir("shortbread-worker-health") do |directory|
      start_file = File.join(directory, "worker-start.json")
      write_start_marker(start_file, started_at: Time.current)

      _, stderr, status = run_worker_health(start_file)

      refute status.success?
      assert_equal "worker health failed\n", stderr
    end
  ensure
    delete_process(stale_worker_id) if stale_worker_id
  end

  test "worker health rejects a fresh same-host Worker unrelated to the current supervisor" do
    unrelated_worker_id = register_process(kind: "Worker", hostname: Socket.gethostname)

    Dir.mktmpdir("shortbread-worker-health") do |directory|
      start_file = File.join(directory, "worker-start.json")
      write_start_marker(start_file, started_at: 1.second.ago, supervisor_pid: 41_421)

      _, stderr, status = run_worker_health(start_file)

      refute status.success?
      assert_equal "worker health failed\n", stderr
    end
  ensure
    delete_process(unrelated_worker_id) if unrelated_worker_id
  end

  test "worker health accepts a fresh Worker registered under the current supervisor" do
    supervisor_pid = 41_422
    supervisor_id = register_process(
      kind: "Supervisor(fork)",
      hostname: Socket.gethostname,
      pid: supervisor_pid
    )
    worker_id = register_process(
      kind: "Worker",
      hostname: Socket.gethostname,
      supervisor_id: supervisor_id
    )

    Dir.mktmpdir("shortbread-worker-health") do |directory|
      start_file = File.join(directory, "worker-start.json")
      write_start_marker(start_file, started_at: 1.second.ago, supervisor_pid: supervisor_pid)

      _, stderr, status = run_worker_health(start_file)

      assert status.success?, stderr
    end
  ensure
    delete_process(worker_id) if worker_id
    delete_process(supervisor_id) if supervisor_id
  end

  private

  def register_process(kind:, hostname:, supervisor_id: nil, pid: Process.pid, created_at: Time.current)
    result = queue_connection.exec_params(<<~SQL, [ kind, SecureRandom.hex(8), pid, hostname, supervisor_id, created_at, Time.current ])
      INSERT INTO solid_queue_processes
        (kind, name, pid, hostname, supervisor_id, metadata, last_heartbeat_at, created_at)
      VALUES
        ($1, $2, $3, $4, $5, '{}', $7, $6)
      RETURNING id
    SQL
    Integer(result.first.fetch("id"))
  end

  def delete_process(id)
    queue_connection.exec_params("DELETE FROM solid_queue_processes WHERE id = $1", [ id ])
  end

  def queue_connection
    @queue_connection ||= PG.connect(
      host: ENV.fetch("SHORTBREAD_DATABASE_HOST"),
      port: ENV.fetch("SHORTBREAD_DATABASE_PORT"),
      dbname: "shortbread_development_queue"
    )
  end

  def write_start_marker(path, started_at:, supervisor_pid: Process.pid, hostname: Socket.gethostname)
    File.write(
      path,
      JSON.generate(
        hostname: hostname,
        supervisor_pid: supervisor_pid,
        started_at: started_at.utc.iso8601(6)
      )
    )
  end

  def run_worker_health(start_file)
    Open3.capture3(
      VALID_ENVIRONMENT.merge(
        "DATABASE_URL" => database_url("shortbread_development"),
        "QUEUE_DATABASE_URL" => database_url("shortbread_development_queue"),
        "SHORTBREAD_WORKER_START_FILE" => start_file
      ),
      Rails.root.join("bin/production").to_s,
      "health",
      "worker",
      chdir: Rails.root.to_s
    )
  end

  def database_url(database)
    socket = URI.encode_www_form_component(ENV.fetch("SHORTBREAD_DATABASE_HOST"))
    port = ENV.fetch("SHORTBREAD_DATABASE_PORT")
    "postgresql://localhost:#{port}/#{database}?host=#{socket}"
  end
end
