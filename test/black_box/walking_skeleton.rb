# frozen_string_literal: true

require "fileutils"
require "json"
require "net/http"
require "open3"
require "securerandom"
require "selenium-webdriver"
require "shellwords"
require "socket"
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
        keys: %w[bytes files id number resource reused status uploaded], resource: "release", status: "published",
        fields: {
          "id" => :positive_integer,
          "number" => :positive_integer,
          "files" => :positive_integer,
          "uploaded" => :nonnegative_integer,
          "reused" => :nonnegative_integer,
          "bytes" => :positive_integer
        },
        returns: %w[id number files uploaded reused bytes]
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
      contract.fetch(:returns).to_h { |key| [ key.to_sym, result.fetch(key) ] }
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
      raise Failure unless result["status"] == contract.fetch(:status)

      contract.fetch(:fields).each do |key, validator|
        raise Failure unless valid_field?(result[key], validator)
      end
      if contract.fetch(:resource) == "release"
        raise Failure unless result["files"] == result["uploaded"] + result["reused"]
      end
      result
    end

    def valid_field?(value, validator)
      case validator
      when :positive_integer
        value.is_a?(Integer) && value.positive?
      when :nonnegative_integer
        value.is_a?(Integer) && value >= 0
      when :true
        value == true
      else
        false
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
    ACCEPT_SELECTOR = '[data-shortbread-invitation-accept="true"]'
    PRIVATE_READY_SELECTOR = '[data-shortbread-private-page-ready="true"]'
    SERVER_TIMEOUT = 30
    BROWSER_TIMEOUT = 20

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
        create_and_publish_site
        prove_unauthenticated_site_is_private
        create_invitation
        accept_invitation_and_open_private_site
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

      fixture = File.join(@bundle_dir, "index.html")
      FileUtils.cp(FIXTURE, fixture)
      File.chmod(0o600, fixture)
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
      raise Failure unless release.fetch(:files) == 1
      raise Failure unless release.fetch(:uploaded) == 1 && release.fetch(:reused).zero?
      raise Failure unless release.fetch(:bytes) == File.size(FIXTURE)
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

    def accept_invitation_and_open_private_site
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
        wait.until { browser.find_elements(css: PRIVATE_READY_SELECTOR).one? }
      end
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
