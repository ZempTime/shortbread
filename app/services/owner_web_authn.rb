# frozen_string_literal: true

require "uri"
require "webauthn"

class OwnerWebAuthn
  LOOPBACK_RP_IDS = %w[localhost 127.0.0.1].freeze

  class InvalidConfiguration < StandardError
    def initialize = super("invalid Owner WebAuthn configuration")
  end

  attr_reader :origin, :rp_id

  def self.configured
    new(
      apex_host: ENV.fetch("SHORTBREAD_APEX_HOST", "localhost"),
      origin: ENV["SHORTBREAD_OWNER_ORIGIN"],
      rp_id: ENV["SHORTBREAD_OWNER_RP_ID"],
      local_environment: Rails.env.local?
    )
  end

  def initialize(apex_host:, origin:, rp_id:, local_environment:)
    @origin = origin
    @rp_id = rp_id
    @apex_host = apex_host
    @local_environment = local_environment
    validate!
  rescue URI::InvalidURIError, Shortbread::Hosts::InvalidHost
    raise InvalidConfiguration
  end

  def relying_party
    @relying_party ||= WebAuthn::RelyingParty.new(
      allowed_origins: [ origin ],
      id: rp_id,
      name: "Shortbread"
    )
  end

  private

  attr_reader :apex_host, :local_environment

  def validate!
    reject! unless origin.is_a?(String) && rp_id.is_a?(String) && rp_id == apex_host

    uri = URI.parse(origin)
    reject! unless uri.is_a?(URI::HTTP) && uri.host == rp_id
    reject! unless uri.userinfo.nil? && uri.path.empty? && uri.query.nil? && uri.fragment.nil?

    host = Shortbread::Hosts.parse(host: rp_id, scheme: uri.scheme, port: uri.port, apex_host:)
    reject! unless host.kind == :apex && host.apex_origin == origin
    reject! if uri.scheme == "http" && (!local_environment || !LOOPBACK_RP_IDS.include?(rp_id))
  end

  def reject!
    raise InvalidConfiguration
  end
end
