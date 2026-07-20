# frozen_string_literal: true

require "digest"
require "securerandom"

class InvitationFlow
  HANDOFF_LIFETIME = 2.minutes
  NONCE_BYTES = 32
  PURPOSE = "site-handoff"
  SECRET_FORMAT = /\A[A-Za-z0-9_-]{43}\z/
  VERIFIER_NAME = "site-handoff"

  Acceptance = Data.define(:token, :site)

  class Rejected < StandardError
    MESSAGE = "invitation flow rejected"

    def initialize = super(MESSAGE)
  end

  class << self
    def accept!(locator:, secret:, audience:)
      new.accept!(locator:, secret:, audience:)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      raise Rejected
    end

    def exchange!(token:, audience:, site:)
      new.exchange!(token:, audience:, site:)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      raise Rejected
    end
  end

  def accept!(locator:, secret:, audience:)
    reject! unless valid_acceptance_input?(locator:, secret:, audience:)

    now = Time.current
    Invitation.transaction do
      invitation = Invitation.lock.find_by(locator:)
      reject! unless invitation

      grant = invitation.grant
      grant.lock!
      reject! unless digest_matches?(secret, invitation.secret_digest)
      reject! unless invitation.pending?(now:)

      nonce = SecureRandom.urlsafe_base64(NONCE_BYTES, false)
      handoff = SiteHandoff.create!(
        grant:,
        invitation:,
        audience:,
        nonce_digest: Digest::SHA256.hexdigest(nonce),
        expires_at: now + HANDOFF_LIFETIME
      )
      invitation.update!(accepted_at: now)

      token = verifier.generate(
        token_claims(handoff:, nonce:),
        purpose: PURPOSE,
        expires_at: handoff.expires_at
      )
      Acceptance.new(token:, site: grant.site)
    end
  end

  def exchange!(token:, audience:, site:)
    reject! unless token.is_a?(String) && token.present?
    reject! unless valid_audience?(audience)
    reject! unless site.is_a?(Site) && site.persisted?

    claims = verified_claims(token)
    now = Time.current

    SiteHandoff.transaction do
      handoff = SiteHandoff.lock.find_by(id: claims["handoff_id"])
      reject! unless handoff

      grant = handoff.grant
      grant.lock!
      reject! unless valid_claims?(claims:, handoff:, grant:, audience:, site:)
      reject! unless handoff.consumed_at.nil? && handoff.expires_at > now
      reject! unless grant.active?

      handoff.update!(consumed_at: now)
      grant
    end
  end

  private

  def digest_matches?(value, expected_digest)
    actual_digest = Digest::SHA256.hexdigest(value)
    expected_digest = expected_digest.to_s
    expected_digest.bytesize == actual_digest.bytesize &&
      ActiveSupport::SecurityUtils.fixed_length_secure_compare(actual_digest, expected_digest)
  end

  def reject!
    raise Rejected
  end

  def token_claims(handoff:, nonce:)
    {
      "handoff_id" => handoff.id,
      "invitation_id" => handoff.invitation_id,
      "grant_id" => handoff.grant_id,
      "site_id" => handoff.grant.site_id,
      "audience" => handoff.audience,
      "nonce" => nonce
    }
  end

  def valid_acceptance_input?(locator:, secret:, audience:)
    locator.is_a?(String) && locator.match?(Invitation::LOCATOR_FORMAT) &&
      secret.is_a?(String) && secret.match?(SECRET_FORMAT) &&
      valid_audience?(audience)
  end

  def valid_audience?(audience)
    audience.is_a?(String) && audience.present? && audience.bytesize <= Shortbread::Hosts::MAX_ORIGIN_BYTES
  end

  def valid_claims?(claims:, handoff:, grant:, audience:, site:)
    claims.is_a?(Hash) &&
      claims["handoff_id"] == handoff.id &&
      claims["invitation_id"] == handoff.invitation_id &&
      claims["grant_id"] == handoff.grant_id &&
      claims["site_id"] == site.id &&
      claims["audience"] == audience &&
      handoff.audience == audience &&
      grant.site_id == site.id &&
      handoff.invitation.grant_id == grant.id &&
      valid_nonce?(claims["nonce"], handoff.nonce_digest)
  end

  def valid_nonce?(nonce, expected_digest)
    nonce.is_a?(String) && nonce.match?(SECRET_FORMAT) && digest_matches?(nonce, expected_digest)
  end

  def verified_claims(token)
    verifier.verify(token, purpose: PURPOSE)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    reject!
  end

  def verifier
    Rails.application.message_verifier(VERIFIER_NAME)
  end
end
