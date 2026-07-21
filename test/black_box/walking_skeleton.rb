# frozen_string_literal: true

require "fileutils"
require "digest"
require "json"
require "net/http"
require "open3"
require "securerandom"
require "selenium-webdriver"
require "shellwords"
require "socket"
require "time"
require "timeout"
require "tmpdir"
require "uri"

module ShortbreadBlackBox
  class Failure < StandardError; end

  class CliRunner
    CONTRACTS = {
      site: {
        keys: %w[id resource status], resource: "site", status: "created",
        fields: { "id" => :positive_integer }, returns: %w[id]
      },
      person: {
        keys: %w[id resource status], resource: "person", status: "created",
        fields: { "id" => :positive_integer }, returns: %w[id]
      },
      grant: {
        keys: %w[id resource status], resource: "grant", status: "created",
        fields: { "id" => :positive_integer }, returns: %w[id]
      },
      invitation: {
        keys: %w[id link_written resource status], resource: "invitation", status: "created",
        fields: { "id" => :positive_integer, "link_written" => :true }, returns: %w[id link_written]
      },
      publish: {
        keys: %w[added bytes changed files id number removed resource reused status uploaded], resource: "release", status: "published",
        fields: {
          "id" => :positive_integer,
          "number" => :positive_integer,
          "files" => :positive_integer,
          "uploaded" => :nonnegative_integer,
          "added" => :nonnegative_integer,
          "changed" => :nonnegative_integer,
          "reused" => :nonnegative_integer,
          "removed" => :nonnegative_integer,
          "bytes" => :positive_integer
        },
        returns: %w[id number files uploaded added changed reused removed bytes]
      },
      release_history: {
        keys: %w[current_release_number pagination releases resource site_slug],
        resource: "release_history",
        fields: {
          "site_slug" => :site_slug,
          "current_release_number" => :nullable_positive_integer,
          "releases" => :release_summaries,
          "pagination" => :release_pagination
        },
        returns: %w[site_slug current_release_number releases pagination]
      },
      release_rollback: {
        keys: %w[changed from_release_number id recorded_at resource resulting_release_number site_slug status to_release_number],
        resource: "release_rollback",
        fields: {
          "status" => :rollback_status,
          "id" => :positive_integer,
          "site_slug" => :site_slug,
          "from_release_number" => :positive_integer,
          "to_release_number" => :positive_integer,
          "resulting_release_number" => :positive_integer,
          "changed" => :boolean,
          "recorded_at" => :iso8601_timestamp
        },
        returns: %w[id site_slug from_release_number to_release_number resulting_release_number changed recorded_at]
      }
    }.freeze

    def initialize(executable:, server_origin:, token:, chdir:, environment: {})
      @executable = executable
      @server_origin = server_origin
      @token = token.to_s.dup
      @chdir = chdir
      @environment = environment.to_h.transform_values { |value| value.to_s.dup }
    end

    def call(contract_name, *arguments)
      contract = CONTRACTS.fetch(contract_name)
      payload = nil
      stdout, stderr, status = Open3.capture3(
        @environment.merge("SHORTBREAD_TOKEN" => @token),
        @executable,
        "--server", @server_origin,
        "--json",
        *arguments,
        chdir: @chdir
      )
      raise Failure unless status.success? && stderr.empty?

      payload = JSON.parse(stdout)
      result = validated_result(payload, contract)
      contract.fetch(:returns).to_h { |key| [ key.to_sym, duplicate_public_value(result.fetch(key)) ] }
    rescue Failure
      raise
    rescue StandardError
      raise Failure
    ensure
      scrub_values(payload)
      stdout&.replace("")
      stderr&.replace("")
    end

    def clear
      @token&.replace("")
      @environment.each_value { |value| value.replace("") }
    end

    private

    def validated_result(payload, contract)
      exact_keys = payload.is_a?(Hash) && payload.keys.sort == %w[ok result]
      raise Failure unless exact_keys && payload["ok"] == true && payload["result"].is_a?(Hash)

      result = payload.fetch("result")
      raise Failure unless result.keys.sort == contract.fetch(:keys)
      raise Failure unless result["resource"] == contract.fetch(:resource)
      raise Failure if contract.key?(:status) && result["status"] != contract.fetch(:status)

      contract.fetch(:fields).each do |key, validator|
        raise Failure unless valid_field?(result[key], validator)
      end
      if contract.fetch(:resource) == "release"
        raise Failure unless result["files"] == result.values_at("added", "changed", "reused").sum
        raise Failure unless result["uploaded"] <= result["added"] + result["changed"]
      elsif contract.fetch(:resource) == "release_history"
        current = result.fetch("current_release_number")
        current_releases = result.fetch("releases").select { |release| release.fetch("current") }
        if current.nil?
          raise Failure unless result.fetch("releases").empty?
        else
          raise Failure if current_releases.length > 1
          raise Failure if current_releases.one? && current_releases.first.fetch("number") != current
        end
      elsif contract.fetch(:resource) == "release_rollback"
        raise Failure unless result["to_release_number"] == result["resulting_release_number"]
        changed = result.fetch("changed")
        same_release = result["from_release_number"] == result["to_release_number"]
        coherent = result.fetch("status") == "rolled_back" ? changed && !same_release : !changed && same_release
        raise Failure unless coherent
      end
      result
    end

    def valid_field?(value, validator)
      case validator
      when :positive_integer
        value.is_a?(Integer) && value.positive?
      when :nonnegative_integer
        value.is_a?(Integer) && value >= 0
      when :nullable_positive_integer
        value.nil? || valid_field?(value, :positive_integer)
      when :true
        value == true
      when :boolean
        value == true || value == false
      when :sha256
        value.is_a?(String) && value.match?(/\A[0-9a-f]{64}\z/)
      when :site_slug
        value.is_a?(String) && value.bytesize <= 63 && value.match?(/\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/)
      when :iso8601_timestamp
        valid_timestamp?(value)
      when :release_summaries
        valid_release_summaries?(value)
      when :release_pagination
        valid_release_pagination?(value)
      when :rollback_status
        %w[already_current rolled_back].include?(value)
      else
        false
      end
    end

    def valid_timestamp?(value)
      value.is_a?(String) && value.end_with?("Z") && Time.iso8601(value)
    rescue ArgumentError
      false
    end

    def valid_release_summaries?(value)
      return false unless value.is_a?(Array)

      numbers = value.map do |release|
        return false unless release.is_a?(Hash)
        return false unless release.keys.sort == %w[bytes current files finalized_at id manifest_sha256 number]
        return false unless valid_field?(release["id"], :positive_integer)
        return false unless valid_field?(release["number"], :positive_integer)
        return false unless valid_field?(release["manifest_sha256"], :sha256)
        return false unless valid_field?(release["finalized_at"], :iso8601_timestamp)
        return false unless valid_field?(release["current"], :boolean)
        return false unless valid_field?(release["files"], :positive_integer)
        return false unless valid_field?(release["bytes"], :nonnegative_integer)

        release.fetch("number")
      end
      numbers == numbers.sort.reverse && numbers.uniq == numbers
    end

    def valid_release_pagination?(value)
      value.is_a?(Hash) &&
        value.keys.sort == %w[limit next_before] &&
        value["limit"].is_a?(Integer) && value["limit"].between?(1, 100) &&
        (value["next_before"].nil? || valid_field?(value["next_before"], :positive_integer))
    end

    def duplicate_public_value(value)
      case value
      when Hash
        value.to_h { |key, nested| [ key.dup, duplicate_public_value(nested) ] }
      when Array
        value.map { |nested| duplicate_public_value(nested) }
      when String
        value.dup
      else
        value
      end
    end

    def scrub_values(value)
      case value
      when Hash
        value.each_value { |nested| scrub_values(nested) }
      when Array
        value.each { |nested| scrub_values(nested) }
      when String
        value.replace("")
      end
    end
  end

  class TemporaryWorkspace
    attr_reader :root

    def initialize(tmpdir: File.realpath(Dir.tmpdir))
      @root = Dir.mktmpdir("sb-ws-", tmpdir)
      File.chmod(0o700, @root)
    end

    def cleanup(processes_stopped:)
      return false unless processes_stopped

      FileUtils.remove_entry_secure(@root)
      !File.exist?(@root)
    rescue StandardError
      false
    end
  end

  class ProcessTerminator
    def initialize(pid:, pgid: nil, term_timeout: 3, kill_timeout: 2)
      @pid = Integer(pid)
      @pgid = pgid && Integer(pgid)
      @term_timeout = term_timeout
      @kill_timeout = kill_timeout
    end

    def stop
      reap
      return true unless alive?

      signal("TERM")
      return true if wait_until_stopped(@term_timeout)

      signal("KILL")
      wait_until_stopped(@kill_timeout)
    end

    def alive?
      reap
      pid_alive? || (safe_process_group? && process_group_alive?)
    end

    private

    def signal(name)
      Process.kill(name, safe_process_group? ? -@pgid : @pid)
    rescue Errno::ESRCH
      nil
    end

    def wait_until_stopped(timeout)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      loop do
        return true unless alive?
        return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep 0.02
      end
    end

    def reap
      Process.waitpid(@pid, Process::WNOHANG)
    rescue Errno::ECHILD
      nil
    end

    def pid_alive?
      Process.kill(0, @pid)
      true
    rescue Errno::ESRCH
      false
    rescue Errno::EPERM
      true
    end

    def process_group_alive?
      Process.kill(0, -@pgid)
      true
    rescue Errno::ESRCH
      false
    rescue Errno::EPERM
      true
    end

    def safe_process_group?
      @pgid && @pgid > 1 && @pgid != Process.getpgrp
    end
  end

  class EphemeralDatabase
    PORT = 55_432
    COMMAND_TIMEOUT = 30
    STOP_TIMEOUT = 5

    attr_reader :url

    def initialize(root)
      @data_dir = File.join(root, "postgres-data")
      @socket_dir = root
      @database = "shortbread_walking_skeleton_#{SecureRandom.hex(8)}"
      query = URI.encode_www_form(host: @socket_dir, port: PORT)
      @url = "postgresql://localhost/#{@database}?#{query}"
      @started = false
      validate_socket_path!
    end

    def start
      FileUtils.mkdir_p(@data_dir, mode: 0o700)
      File.chmod(0o700, @data_dir)

      run("initdb", "--auth=trust", "--encoding=UTF8", "--no-locale", "-D", @data_dir)
      options = "-k #{Shellwords.escape(@socket_dir)} -p #{PORT} -h ''"
      run("pg_ctl", "-D", @data_dir, "-l", File::NULL, "-o", options, "-w", "start")
      @started = true
      capture_postmaster!
      run("createdb", "--host", @socket_dir, "--port", PORT.to_s, @database)
    end

    def stop
      return true unless @started

      command_success?(
        "pg_ctl", "-D", @data_dir, "-m", "fast", "-t", STOP_TIMEOUT.to_s, "-w", "stop",
        timeout: STOP_TIMEOUT + 2
      )
      stopped = wait_for_shutdown(1)
      stopped = @postmaster&.stop unless stopped || @postmaster.nil?
      stopped &&= wait_for_shutdown(1)
      raise Failure unless stopped

      @started = false
      @postmaster = nil
      true
    end

    private

    def run(*command)
      raise Failure unless command_success?(*command, timeout: COMMAND_TIMEOUT)
    end

    def command_success?(*command, timeout:)
      pid = Process.spawn(*command, out: File::NULL, err: File::NULL, pgroup: true)
      _waited_pid, status = Timeout.timeout(timeout) { Process.wait2(pid) }
      status.success?
    rescue Timeout::Error, Errno::ECHILD
      ProcessTerminator.new(pid:, pgid: pid, term_timeout: 0.5, kill_timeout: 1).stop if pid
      false
    rescue StandardError
      false
    end

    def capture_postmaster!
      pid = Integer(File.open(postmaster_pid_path, &:readline).strip, 10)
      raise Failure unless pid > 1

      pgid = Process.getpgid(pid)
      @postmaster = ProcessTerminator.new(pid:, pgid:, term_timeout: STOP_TIMEOUT, kill_timeout: 2)
      raise Failure unless @postmaster.alive?
    rescue ArgumentError, Errno::ENOENT, Errno::ESRCH
      raise Failure
    end

    def wait_for_shutdown(timeout)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      loop do
        return true if postmaster_stopped?
        return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep 0.02
      end
    end

    def postmaster_stopped?
      return !@postmaster.alive? if @postmaster

      !File.exist?(postmaster_pid_path)
    end

    def postmaster_pid_path
      File.join(@data_dir, "postmaster.pid")
    end

    def validate_socket_path!
      Socket.pack_sockaddr_un(File.join(@socket_dir, ".s.PGSQL.#{PORT}"))
    rescue ArgumentError
      raise Failure
    end
  end

  class WalkingSkeleton
    APP_ROOT = File.expand_path("../..", __dir__)
    FIXTURE = File.join(__dir__, "fixtures", "private_site", "index.html")
    APEX_HOST = "shortbread.localhost"
    SITE_SLUG = "walking-skeleton"
    RETRY_SITE_SLUG = "retry-evidence"
    ACCEPT_SELECTOR = '[data-shortbread-invitation-accept="true"]'
    PRIVATE_READY_SELECTOR = '[data-shortbread-private-page-ready="true"]'
    RELEASE_MARKER_SELECTOR = '[data-shortbread-release-marker="%d"]'
    SERVER_TIMEOUT = 30
    BROWSER_TIMEOUT = 20
    SHARED_STYLESHEET = "body { color: #123456; }\n"
    REMOVED_SCRIPT = "window.syntheticRemoved = true;\n"
    ADDED_METADATA = "{\"synthetic\":true}\n"
    RETRY_BODY = "<!doctype html><main data-shortbread-retry=\"true\"></main>\n"

    def run
      success = false
      begin
        @workspace = TemporaryWorkspace.new
        @root = @workspace.root
        prepare_directories
        start_database
        prepare_application
        build_cli
        start_server
        prove_api_retry_contracts
        create_and_publish_site
        prove_unauthenticated_site_is_private
        create_invitation
        accept_invitation_and_prove_release_cycle
        success = true
      rescue StandardError
        success = false
      ensure
        cleanup_succeeded = cleanup
        success &&= cleanup_succeeded
      end
      success
    rescue StandardError
      false
    end

    private

    def prepare_directories
      @bundle_dir = private_directory("bundle")
      @blob_dir = private_directory("blobs")
      @link_dir = private_directory("link")
      @browser_dir = private_directory("browser")
      @cli_path = File.join(@root, "shortbread")
      @link_path = File.join(@link_dir, "invitation")

      @release_one_contents = {
        "index.html" => release_index(1),
        "removed.js" => REMOVED_SCRIPT,
        "shared.css" => SHARED_STYLESHEET
      }
      write_bundle(@release_one_contents)
    end

    def private_directory(name)
      path = File.join(@root, name)
      Dir.mkdir(path, 0o700)
      path
    end

    def start_database
      @database = EphemeralDatabase.new(@root)
      @database.start
    end

    def prepare_application
      @token = SecureRandom.urlsafe_base64(48, false)
      @server_port = available_port
      @server_origin = "http://#{APEX_HOST}:#{@server_port}"
      @site_origin = "http://#{SITE_SLUG}.sites.#{APEX_HOST}:#{@server_port}"
      @application_env = {
        "DATABASE_URL" => @database.url,
        "PIDFILE" => File.join(@root, "rails.pid"),
        "RAILS_ENV" => "test",
        "RAILS_LOG_LEVEL" => "fatal",
        "RAILS_LOG_TO_STDOUT" => "true",
        "SHORTBREAD_APEX_HOST" => APEX_HOST,
        "SHORTBREAD_BLOB_ROOT" => @blob_dir,
        "SHORTBREAD_BOOTSTRAP_TOKEN" => @token
      }
      run_silently(@application_env, "bin/rails", "db:schema:load", chdir: APP_ROOT)
    end

    def build_cli
      run_silently({}, "go", "build", "-mod=readonly", "-o", @cli_path, "./cmd/shortbread",
        chdir: File.join(APP_ROOT, "cli"))
      File.chmod(0o700, @cli_path)
      @cli = CliRunner.new(
        executable: @cli_path,
        server_origin: @server_origin,
        token: @token,
        chdir: APP_ROOT
      )
    end

    def prove_api_retry_contracts
      @cli.call(:site, "sites", "create", "--slug", RETRY_SITE_SLUG, "--name", "Retry Evidence")
      contents = { "index.html" => RETRY_BODY }
      first_key = SecureRandom.urlsafe_base64(32, false)
      second_key = SecureRandom.urlsafe_base64(32, false)
      rollback_key = SecureRandom.urlsafe_base64(32, false)

      status, first_plan = create_publish_plan(RETRY_SITE_SLUG, contents, first_key)
      raise Failure unless status == 201
      validate_publish_plan(
        first_plan,
        expected_delta: { "added" => 1, "changed" => 0, "reused" => 0, "removed" => 0 },
        expected_upload_digests: content_digests(contents)
      )
      replay_status, replayed_plan = create_publish_plan(RETRY_SITE_SLUG, contents, first_key)
      raise Failure unless replay_status == 200 && replayed_plan == first_plan

      2.times do
        status, payload = finalize_publish_plan(first_plan)
        raise Failure unless status == 409 && payload == { "error" => { "code" => "publish_incomplete" } }
        assert_api_history(site_slug: RETRY_SITE_SLUG, current: nil, numbers: [])
      end

      upload_missing(first_plan, contents)
      status, first_release = finalize_publish_plan(first_plan)
      raise Failure unless status == 201
      replay_status, replayed_release = finalize_publish_plan(first_plan)
      raise Failure unless replay_status == 200 && replayed_release == first_release
      raise Failure unless first_release.dig("release", "number") == 1
      assert_api_history(
        site_slug: RETRY_SITE_SLUG,
        current: 1,
        numbers: [ 1 ],
        files: { 1 => 1 },
        bytes: { 1 => RETRY_BODY.bytesize }
      )

      status, second_plan = create_publish_plan(RETRY_SITE_SLUG, contents, second_key)
      raise Failure unless status == 201
      validate_publish_plan(
        second_plan,
        expected_delta: { "added" => 0, "changed" => 0, "reused" => 1, "removed" => 0 },
        expected_upload_digests: []
      )
      status, second_release = finalize_publish_plan(second_plan)
      raise Failure unless status == 201 && second_release.dig("release", "number") == 2

      status, first_rollback = rollback_release(RETRY_SITE_SLUG, 1, rollback_key)
      raise Failure unless status == 201
      validate_rollback(first_rollback, site_slug: RETRY_SITE_SLUG, from: 2, to: 1, changed: true)
      replay_status, replayed_rollback = rollback_release(RETRY_SITE_SLUG, 1, rollback_key)
      raise Failure unless replay_status == 200 && replayed_rollback == first_rollback
      assert_api_history(site_slug: RETRY_SITE_SLUG, current: 1, numbers: [ 2, 1 ])
    ensure
      first_key&.replace("")
      second_key&.replace("")
      rollback_key&.replace("")
    end

    def start_server
      command = [
        "bin/rails", "server", "--environment=test", "--binding=127.0.0.1",
        "--port=#{@server_port}", "--pid=#{@application_env.fetch("PIDFILE")}", "--log-to-stdout"
      ]
      @server_pid = Process.spawn(
        @application_env,
        *command,
        chdir: APP_ROOT,
        out: File::NULL,
        err: File::NULL,
        pgroup: true
      )
      @server_process = ProcessTerminator.new(pid: @server_pid, pgid: @server_pid, term_timeout: 5, kill_timeout: 2)
      wait_for_server
    end

    def wait_for_server
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + SERVER_TIMEOUT
      loop do
        return if health_ready?
        raise Failure if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep 0.05
      end
    end

    def health_ready?
      http = Net::HTTP.new("127.0.0.1", @server_port)
      http.open_timeout = 0.25
      http.read_timeout = 0.25
      request = Net::HTTP::Head.new("/up")
      request["Host"] = "#{APEX_HOST}:#{@server_port}"
      http.request(request).code == "200"
    rescue SystemCallError, IOError, Timeout::Error
      false
    end

    def create_and_publish_site
      @cli.call(:site, "sites", "create", "--slug", SITE_SLUG, "--name", "Walking Skeleton")
      person = @cli.call(:person, "people", "add", "--first-name", "Avery")
      grant = @cli.call(
        :grant, "access", "grant", "--site", SITE_SLUG, "--person", person.fetch(:id).to_s
      )
      @grant_id = grant.fetch(:id)
      release = @cli.call(:publish, "publish", @bundle_dir, "--site", SITE_SLUG)
      raise Failure unless release.fetch(:number) == 1
      raise Failure unless release.fetch(:files) == 3
      raise Failure unless release.values_at(:uploaded, :added, :changed, :reused, :removed) == [ 3, 3, 0, 0, 0 ]
      raise Failure unless release.fetch(:bytes) == total_bytes(@release_one_contents)
    end

    def create_invitation
      @cli.call(
        :invitation, "invite", "create", "--grant", @grant_id.to_s, "--link-file", @link_path
      )
      @invitation_link = read_and_delete_private_link
    end

    def read_and_delete_private_link
      stat = File.lstat(@link_path)
      raise Failure unless stat.file? && !stat.symlink? && stat.mode & 0o777 == 0o600

      File.binread(@link_path)
    rescue Errno::ENOENT
      raise Failure
    ensure
      begin
        File.unlink(@link_path)
      rescue Errno::ENOENT
        nil
      end
    end

    def prove_unauthenticated_site_is_private
      response = site_head
      raise Failure unless response.code == "404"

      with_browser("unauthenticated") do |browser|
        browser.navigate.to(@site_origin)
        raise Failure unless browser.find_elements(css: PRIVATE_READY_SELECTOR).empty?
      end
    end

    def site_head
      http = Net::HTTP.new("127.0.0.1", @server_port)
      http.open_timeout = 1
      http.read_timeout = 1
      request = Net::HTTP::Head.new("/")
      request["Host"] = "#{SITE_SLUG}.sites.#{APEX_HOST}:#{@server_port}"
      http.request(request)
    end

    def accept_invitation_and_prove_release_cycle
      with_browser("invited") do |browser|
        begin
          browser.navigate.to(@invitation_link)
        ensure
          @invitation_link&.replace("")
        end

        wait = Selenium::WebDriver::Wait.new(timeout: BROWSER_TIMEOUT, interval: 0.05)
        button = wait.until do
          matches = browser.find_elements(css: ACCEPT_SELECTOR)
          matches.first if matches.one?
        end
        raise Failure unless browser.find_elements(css: PRIVATE_READY_SELECTOR).empty?

        button.click
        wait.until { browser.find_elements(css: format(RELEASE_MARKER_SELECTOR, 1)).one? }
        assert_browser_release(browser, 1)

        prepare_release_two_bundle
        prove_incomplete_release_two_plan
        second_release = @cli.call(:publish, "publish", @bundle_dir, "--site", SITE_SLUG)
        raise Failure unless second_release.fetch(:number) == 2
        raise Failure unless second_release.fetch(:files) == 3
        raise Failure unless second_release.values_at(:uploaded, :added, :changed, :reused, :removed) == [ 2, 1, 1, 1, 1 ]
        raise Failure unless second_release.fetch(:bytes) == total_bytes(@release_two_contents)

        browser.navigate.to("#{@site_origin}/?release-check=2")
        assert_browser_release(browser, 2)
        assert_cli_release_history(current: 2)

        rollback = @cli.call(
          :release_rollback,
          "releases", "rollback", "--site", SITE_SLUG, "--release", "1"
        )
        raise Failure unless rollback.fetch(:site_slug) == SITE_SLUG
        raise Failure unless rollback.values_at(
          :from_release_number, :to_release_number, :resulting_release_number, :changed
        ) == [ 2, 1, 1, true ]
        prove_rollback_replay_after_cli

        browser.navigate.to("#{@site_origin}/?release-check=1")
        assert_browser_release(browser, 1)
      end
    end

    def prepare_release_two_bundle
      @release_two_contents = {
        "added.json" => ADDED_METADATA,
        "index.html" => release_index(2),
        "shared.css" => SHARED_STYLESHEET
      }
      File.unlink(File.join(@bundle_dir, "removed.js"))
      write_bundle(@release_two_contents)
    end

    def prove_incomplete_release_two_plan
      key = SecureRandom.urlsafe_base64(32, false)
      status, plan = create_publish_plan(SITE_SLUG, @release_two_contents, key)
      raise Failure unless status == 201
      expected_uploads = content_digests(
        "added.json" => @release_two_contents.fetch("added.json"),
        "index.html" => @release_two_contents.fetch("index.html")
      )
      validate_publish_plan(
        plan,
        expected_delta: { "added" => 1, "changed" => 1, "reused" => 1, "removed" => 1 },
        expected_upload_digests: expected_uploads
      )

      replay_status, replayed_plan = create_publish_plan(SITE_SLUG, @release_two_contents, key)
      raise Failure unless replay_status == 200 && replayed_plan == plan
      2.times do
        finalize_status, payload = finalize_publish_plan(plan)
        raise Failure unless finalize_status == 409
        raise Failure unless payload == { "error" => { "code" => "publish_incomplete" } }
        assert_api_history(
          site_slug: SITE_SLUG,
          current: 1,
          numbers: [ 1 ],
          files: { 1 => 3 },
          bytes: { 1 => total_bytes(@release_one_contents) }
        )
      end
    ensure
      key&.replace("")
    end

    def assert_cli_release_history(current:)
      history = @cli.call(:release_history, "releases", "list", "--site", SITE_SLUG)
      raise Failure unless history.fetch(:site_slug) == SITE_SLUG
      raise Failure unless history.fetch(:current_release_number) == current
      releases = history.fetch(:releases)
      raise Failure unless releases.map { |release| release.fetch("number") } == [ 2, 1 ]
      raise Failure unless releases.map { |release| release.fetch("current") } == [ current == 2, current == 1 ]
      raise Failure unless releases.map { |release| release.fetch("files") } == [ 3, 3 ]
      raise Failure unless releases.map { |release| release.fetch("bytes") } == [
        total_bytes(@release_two_contents), total_bytes(@release_one_contents)
      ]
      raise Failure unless releases.map { |release| release.fetch("manifest_sha256") }.uniq.length == 2
      raise Failure unless history.fetch(:pagination) == { "limit" => 50, "next_before" => nil }
    end

    def prove_rollback_replay_after_cli
      key = SecureRandom.urlsafe_base64(32, false)
      status, first = rollback_release(SITE_SLUG, 1, key)
      raise Failure unless status == 201
      validate_rollback(first, site_slug: SITE_SLUG, from: 1, to: 1, changed: false)
      replay_status, replay = rollback_release(SITE_SLUG, 1, key)
      raise Failure unless replay_status == 200 && replay == first
      assert_api_history(site_slug: SITE_SLUG, current: 1, numbers: [ 2, 1 ])
      assert_cli_release_history(current: 1)
    ensure
      key&.replace("")
    end

    def assert_browser_release(browser, number)
      wait = Selenium::WebDriver::Wait.new(timeout: BROWSER_TIMEOUT, interval: 0.05)
      wait.until { browser.find_elements(css: format(RELEASE_MARKER_SELECTOR, number)).one? }
      raise Failure unless browser.find_elements(css: PRIVATE_READY_SELECTOR).one?
      other = number == 1 ? 2 : 1
      raise Failure unless browser.find_elements(css: format(RELEASE_MARKER_SELECTOR, other)).empty?

      actual = URI(browser.current_url)
      expected = URI(@site_origin)
      raise Failure unless actual.scheme == expected.scheme && actual.host == expected.host && actual.port == expected.port
    end

    def release_index(number)
      source = File.binread(FIXTURE)
      marker = %(data-shortbread-private-page-ready="true")
      replacement = %(#{marker} data-shortbread-release-marker="#{number}")
      body = source.sub(marker, replacement)
      raise Failure if body == source

      body
    ensure
      source&.replace("")
    end

    def write_bundle(contents)
      contents.each do |relative_path, body|
        path = File.join(@bundle_dir, relative_path)
        File.open(path, File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |file|
          file.binmode
          file.write(body)
        end
        File.chmod(0o600, path)
      end
    end

    def total_bytes(contents)
      contents.values.sum(&:bytesize)
    end

    def content_digests(contents)
      contents.values.map { |body| Digest::SHA256.hexdigest(body) }.uniq.sort
    end

    def manifest_entries(contents)
      contents.sort.map do |path, body|
        {
          path:,
          sha256: Digest::SHA256.hexdigest(body),
          size: body.bytesize,
          content_type: content_type(path),
          offline_policy: "required"
        }
      end
    end

    def content_type(path)
      case File.extname(path)
      when ".css" then "text/css"
      when ".html" then "text/html"
      when ".js" then "text/javascript"
      when ".json" then "application/json"
      else raise Failure
      end
    end

    def create_publish_plan(site_slug, contents, idempotency_key)
      status, payload = api_request(
        :post,
        "/api/v1/sites/#{site_slug}/publish-plans",
        json: { manifest: { entries: manifest_entries(contents) } },
        headers: { "Idempotency-Key" => idempotency_key }
      )
      raise Failure unless payload.is_a?(Hash) && payload.keys == [ "publish_plan" ]

      [ status, payload.fetch("publish_plan") ]
    end

    def finalize_publish_plan(plan)
      api_request(:post, plan.fetch("finalize_url"), json: {})
    end

    def rollback_release(site_slug, number, idempotency_key)
      api_request(
        :post,
        "/api/v1/sites/#{site_slug}/releases/#{number}/rollback",
        json: {},
        headers: { "Idempotency-Key" => idempotency_key }
      )
    end

    def upload_missing(plan, contents)
      bodies = contents.values.to_h { |body| [ Digest::SHA256.hexdigest(body), body ] }
      plan.fetch("uploads").each do |upload|
        status, payload = api_request(
          :put,
          upload.fetch("url"),
          body: bodies.fetch(upload.fetch("sha256")),
          headers: { "Content-Type" => "application/octet-stream" }
        )
        raise Failure unless status == 204 && payload.nil?
      end
    end

    def validate_publish_plan(plan, expected_delta:, expected_upload_digests:)
      raise Failure unless plan.is_a?(Hash)
      raise Failure unless plan.keys.sort == %w[delta finalize_url id state uploads]
      raise Failure unless plan.fetch("id").is_a?(Integer) && plan.fetch("id").positive?
      raise Failure unless plan.fetch("state") == "open"
      raise Failure unless plan.fetch("finalize_url") == "/api/v1/publish-plans/#{plan.fetch("id")}/finalize"
      raise Failure unless plan.fetch("delta") == expected_delta
      uploads = plan.fetch("uploads")
      raise Failure unless uploads.is_a?(Array)
      raise Failure unless uploads.map { |upload| upload.fetch("sha256") }.sort == expected_upload_digests.sort
      uploads.each do |upload|
        raise Failure unless upload.keys.sort == %w[headers method sha256 size url]
        raise Failure unless upload.fetch("method") == "PUT"
        raise Failure unless upload.fetch("headers") == { "Content-Type" => "application/octet-stream" }
        raise Failure unless upload.fetch("sha256").match?(/\A[0-9a-f]{64}\z/)
        raise Failure unless upload.fetch("size").is_a?(Integer) && upload.fetch("size") >= 0
        expected_url = "/api/v1/publish-plans/#{plan.fetch("id")}/blobs/#{upload.fetch("sha256")}"
        raise Failure unless upload.fetch("url") == expected_url
      end
    end

    def validate_rollback(payload, site_slug:, from:, to:, changed:)
      raise Failure unless payload.is_a?(Hash) && payload.keys == [ "rollback" ]
      rollback = payload.fetch("rollback")
      raise Failure unless rollback.keys.sort == %w[changed from_release_number id recorded_at resulting_release_number site_slug to_release_number]
      raise Failure unless rollback.fetch("id").is_a?(Integer) && rollback.fetch("id").positive?
      raise Failure unless rollback.fetch("site_slug") == site_slug
      raise Failure unless rollback.values_at(
        "from_release_number", "to_release_number", "resulting_release_number", "changed"
      ) == [ from, to, to, changed ]
      raise Failure unless rollback.fetch("recorded_at").end_with?("Z")
      Time.iso8601(rollback.fetch("recorded_at"))
    rescue ArgumentError
      raise Failure
    end

    def assert_api_history(site_slug:, current:, numbers:, files: nil, bytes: nil)
      status, payload = api_request(:get, "/api/v1/sites/#{site_slug}/releases")
      raise Failure unless status == 200 && payload.is_a?(Hash)
      raise Failure unless payload.keys.sort == %w[pagination releases site]
      raise Failure unless payload.fetch("site") == {
        "slug" => site_slug,
        "current_release_number" => current
      }
      raise Failure unless payload.fetch("pagination") == { "limit" => 50, "next_before" => nil }
      releases = payload.fetch("releases")
      raise Failure unless releases.map { |release| release.fetch("number") } == numbers
      releases.each do |release|
        raise Failure unless release.keys.sort == %w[bytes current files finalized_at id manifest_sha256 number]
        raise Failure unless release.fetch("id").is_a?(Integer) && release.fetch("id").positive?
        raise Failure unless release.fetch("manifest_sha256").match?(/\A[0-9a-f]{64}\z/)
        raise Failure unless release.fetch("current") == (release.fetch("number") == current)
        raise Failure unless release.fetch("files").is_a?(Integer) && release.fetch("files").positive?
        raise Failure unless release.fetch("bytes").is_a?(Integer) && release.fetch("bytes") >= 0
        Time.iso8601(release.fetch("finalized_at"))
      end
      files&.each { |number, count| raise Failure unless releases.find { |release| release["number"] == number }&.fetch("files") == count }
      bytes&.each { |number, count| raise Failure unless releases.find { |release| release["number"] == number }&.fetch("bytes") == count }
    rescue ArgumentError
      raise Failure
    end

    def api_request(method, path, json: nil, body: nil, headers: {})
      request_class = { get: Net::HTTP::Get, post: Net::HTTP::Post, put: Net::HTTP::Put }.fetch(method)
      request = request_class.new(path)
      request["Host"] = "#{APEX_HOST}:#{@server_port}"
      request["Authorization"] = "Bearer #{@token}"
      request["Accept"] = "application/json"
      headers.each { |name, value| request[name] = value }
      if json
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(json)
      elsif body
        request.body = body.dup
      end

      http = Net::HTTP.new("127.0.0.1", @server_port)
      http.open_timeout = 2
      http.read_timeout = 5
      response = http.request(request)
      raw = response.body.to_s.dup
      payload = raw.empty? ? nil : JSON.parse(raw)
      [ Integer(response.code, 10), payload ]
    rescue JSON::ParserError, KeyError, SystemCallError, IOError, Timeout::Error
      raise Failure
    ensure
      request&.body&.replace("")
      request["Authorization"] = "" if request
      headers.each_key { |name| request[name] = "" } if request
      raw&.replace("")
    end

    def with_browser(profile)
      browser = Selenium::WebDriver.for(
        :chrome,
        options: chrome_options(File.join(@browser_dir, profile)),
        service: Selenium::WebDriver::Service.chrome(path: chromedriver_path, log: File::NULL)
      )
      yield browser
    rescue Selenium::WebDriver::Error::WebDriverError
      raise Failure
    ensure
      begin
        browser&.quit
      rescue Selenium::WebDriver::Error::WebDriverError
        nil
      end
    end

    def chrome_options(profile_dir)
      options = Selenium::WebDriver::Chrome::Options.new(binary: chrome_binary)
      [
        "--headless=new",
        "--disable-background-networking",
        "--disable-breakpad",
        "--disable-component-update",
        "--disable-default-apps",
        "--disable-domain-reliability",
        "--disable-extensions",
        "--disable-logging",
        "--disable-sync",
        "--metrics-recording-only",
        "--no-default-browser-check",
        "--no-first-run",
        "--no-proxy-server",
        "--log-level=3",
        "--user-data-dir=#{profile_dir}",
        "--host-resolver-rules=MAP #{APEX_HOST} 127.0.0.1, MAP #{SITE_SLUG}.sites.#{APEX_HOST} 127.0.0.1"
      ].each { |argument| options.add_argument(argument) }
      options
    end

    def chrome_binary
      @chrome_binary ||= begin
        candidates = [
          ENV["SHORTBREAD_CHROME_BINARY"],
          "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
          executable_on_path("google-chrome"),
          executable_on_path("google-chrome-stable"),
          executable_on_path("chromium"),
          executable_on_path("chromium-browser")
        ].compact
        candidates.find { |path| compatible_executable?(path, "Google Chrome", "Chromium") } || raise(Failure)
      end
    end

    def chromedriver_path
      @chromedriver_path ||= begin
        candidates = [ ENV["SHORTBREAD_CHROMEDRIVER"], executable_on_path("chromedriver") ].compact
        candidates.concat(cached_chromedrivers)
        candidates.find { |path| compatible_executable?(path, "ChromeDriver") } || raise(Failure)
      end
    end

    def cached_chromedrivers
      cache_root = ENV.fetch("XDG_CACHE_HOME", File.join(Dir.home, ".cache"))
      Dir.glob(File.join(cache_root, "selenium", "chromedriver", "**", "chromedriver")).reverse
    end

    def compatible_executable?(path, *labels)
      return false unless File.file?(path) && File.executable?(path)

      output, status = Open3.capture2e(path, "--version")
      return false unless status.success? && labels.any? { |label| output.include?(label) }

      major = output[/\b(\d+)\./, 1]
      if labels.include?("ChromeDriver")
        major == chrome_major
      else
        @chrome_major ||= major
        !major.nil?
      end
    ensure
      output&.replace("")
    end

    def chrome_major
      chrome_binary
      @chrome_major
    end

    def executable_on_path(name)
      ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).each do |directory|
        candidate = File.join(directory, name)
        return candidate if File.file?(candidate) && File.executable?(candidate)
      end
      nil
    end

    def run_silently(environment, *command, chdir:)
      success = system(environment, *command, chdir:, out: File::NULL, err: File::NULL)
      raise Failure unless success
    end

    def available_port
      server = TCPServer.new("127.0.0.1", 0)
      server.local_address.ip_port
    ensure
      server&.close
    end

    def stop_server
      return true unless @server_process

      raise Failure unless @server_process.stop

      @server_process = nil
      @server_pid = nil
      true
    end

    def cleanup
      values_cleared = cleanup_step do
        clear_sensitive_values
        true
      end
      server_stopped = cleanup_step { stop_server }
      database_stopped = cleanup_step { @database ? @database.stop : true }
      processes_stopped = server_stopped && database_stopped
      workspace_removed = @workspace ? @workspace.cleanup(processes_stopped:) : processes_stopped
      values_cleared && processes_stopped && workspace_removed
    end

    def cleanup_step
      yield == true
    rescue StandardError
      false
    end

    def clear_sensitive_values
      @invitation_link&.replace("")
      @cli&.clear
      @token&.replace("")
    end
  end
end

if $PROGRAM_NAME == __FILE__
  exit(ShortbreadBlackBox::WalkingSkeleton.new.run ? 0 : 1)
end
