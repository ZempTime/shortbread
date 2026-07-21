# frozen_string_literal: true

require "json"
require "socket"
require "time"

module Shortbread
  class WorkerHealth
    DEFAULT_START_FILE = File.expand_path("../../tmp/production-worker-start.json", __dir__)

    class << self
      def mark_started!(path = start_file)
        marker = {
          hostname: Socket.gethostname,
          supervisor_pid: Process.pid,
          started_at: Time.now.utc.iso8601(6)
        }

        File.open(path, File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |file|
          file.write(JSON.generate(marker))
          file.flush
          file.fsync
        end
      end

      def healthy?(path = start_file)
        marker = JSON.parse(File.read(path))
        hostname = marker.fetch("hostname")
        return false unless hostname == Socket.gethostname

        started_at = Time.iso8601(marker.fetch("started_at"))
        supervisor_pid = Integer(marker.fetch("supervisor_pid"))
        alive_since = SolidQueue.process_alive_threshold.ago
        supervisors = SolidQueue::Process.where(
          hostname: hostname,
          pid: supervisor_pid,
          created_at: started_at..,
          last_heartbeat_at: alive_since..
        ).where("kind LIKE ?", "Supervisor%")

        SolidQueue::Process.where(
          kind: "Worker",
          hostname: hostname,
          supervisor_id: supervisors.select(:id),
          created_at: started_at..,
          last_heartbeat_at: alive_since..
        ).exists?
      rescue Errno::ENOENT, JSON::ParserError, KeyError, ArgumentError, TypeError
        false
      end

      private

      def start_file
        ENV.fetch("SHORTBREAD_WORKER_START_FILE", DEFAULT_START_FILE)
      end
    end
  end
end
