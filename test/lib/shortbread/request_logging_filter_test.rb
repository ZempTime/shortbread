# frozen_string_literal: true

require "test_helper"

require "stringio"

class RequestLoggingFilterTest < ActiveSupport::TestCase
  FILTERED = "[FILTERED]"

  test "sensitive domain parameters are filtered" do
    sensitive_parameters = %w[
      first_name
      secret_digest
      invitation_secret
      handoff
      manifest
      idempotency_key
      locator
      challenge
      device_code
      proof_verifier
      recovery
      ceremony_secret
      bootstrap_ceremony
      owner_bootstrap_secret
      public_key_credential
      credential_label
    ].index_with { |name| "synthetic-#{name}" }

    filtered = ActiveSupport::ParameterFilter
      .new(Rails.application.config.filter_parameters)
      .filter(sensitive_parameters)

    assert_equal sensitive_parameters.keys.index_with { FILTERED }, filtered
  end

  test "invitation preview and acceptance paths redact the locator and sensitive query values" do
    preview = request_for(
      "/invitations/synthetic-preview-locator",
      "invitation_secret=synthetic-preview-secret&keep=visible"
    )
    acceptance = request_for(
      "/invitations/synthetic-acceptance-locator/accept",
      "handoff=synthetic-handoff&keep=visible"
    )

    assert_equal "/invitations/#{FILTERED}?invitation_secret=#{FILTERED}&keep=visible", preview.filtered_path
    assert_equal "/invitations/#{FILTERED}/accept?handoff=#{FILTERED}&keep=visible", acceptance.filtered_path
  end

  test "all Invitation path suffixes redact the locator while unrelated paths remain intact" do
    unrelated = request_for(
      "/sites/invitations/synthetic-locator",
      "secret=synthetic-secret&keep=visible"
    )
    trailing_slash = request_for("/invitations/synthetic-locator/")
    acceptance_slash = request_for("/invitations/synthetic-locator/accept/")
    unknown_suffix = request_for("/invitations/synthetic-locator/history")

    assert_equal "/sites/invitations/synthetic-locator?secret=#{FILTERED}&keep=visible", unrelated.filtered_path
    assert_equal "/invitations/#{FILTERED}/", trailing_slash.filtered_path
    assert_equal "/invitations/#{FILTERED}/accept/", acceptance_slash.filtered_path
    assert_equal "/invitations/#{FILTERED}/history", unknown_suffix.filtered_path
  end

  test "the Rails request logger never emits locators from any Invitation path shape" do
    locator = "synthetic-request-log-locator"
    secret = "synthetic-request-log-secret"
    output = StringIO.new
    logger = ActiveSupport::Logger.new(output)
    middleware = request_logger(logger).new(->(_env) { [ 200, {}, [] ] })
    paths = [
      "/invitations/#{locator}?invitation_secret=#{secret}",
      "/invitations/#{locator}/",
      "/invitations/#{locator}/accept/",
      "/invitations/#{locator}/history"
    ]

    paths.each do |path|
      env = Rack::MockRequest.env_for(path)
      env["action_dispatch.parameter_filter"] = Rails.application.config.filter_parameters
      _status, _headers, body = middleware.call(env)
      body.close
    end

    assert_includes output.string, "/invitations/#{FILTERED}?invitation_secret=#{FILTERED}"
    assert_includes output.string, "/invitations/#{FILTERED}/accept/"
    assert_includes output.string, "/invitations/#{FILTERED}/history"
    refute_includes output.string, locator
    refute_includes output.string, secret
  end

  private

  def request_for(path, query = "")
    ActionDispatch::TestRequest.create(
      "PATH_INFO" => path,
      "QUERY_STRING" => query,
      "action_dispatch.parameter_filter" => Rails.application.config.filter_parameters
    )
  end

  def request_logger(logger)
    Class.new(Rails::Rack::Logger) do
      define_method(:initialize) do |app|
        super(app)
        @test_logger = logger
      end

      private

      attr_reader :test_logger

      alias_method :logger, :test_logger
    end
  end
end
