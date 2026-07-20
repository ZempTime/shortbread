# frozen_string_literal: true

require "securerandom"

class Invitation < ApplicationRecord
  DEFAULT_LIFETIME = 24.hours
  LOCATOR_BYTES = 24
  MAX_LOCATOR_ATTEMPTS = 3
  DIGEST_FORMAT = /\A[0-9a-f]{64}\z/
  LOCATOR_FORMAT = /\A[A-Za-z0-9_-]{32}\z/

  class InvalidSecretDigest < StandardError; end
  class DuplicateSecretDigest < StandardError; end
  class InactiveGrant < StandardError; end
  class LocatorUnavailable < StandardError; end

  belongs_to :grant
  has_one :site_handoff, dependent: :restrict_with_exception

  attr_readonly :grant_id, :locator, :secret_digest, :expires_at

  validates :locator, presence: true, uniqueness: true, format: { with: LOCATOR_FORMAT }
  validates :secret_digest, presence: true, uniqueness: true, format: { with: DIGEST_FORMAT }
  validates :expires_at, presence: true

  def self.issue!(grant:, secret_digest:, now: Time.current)
    raise InvalidSecretDigest unless secret_digest.to_s.match?(DIGEST_FORMAT)

    grant.with_lock do
      raise InactiveGrant unless grant.active?

      attempts = 0
      loop do
        attempts += 1
        invitation = new(
          grant:,
          secret_digest:,
          locator: SecureRandom.urlsafe_base64(LOCATOR_BYTES, false),
          expires_at: now + DEFAULT_LIFETIME
        )

        begin
          Invitation.transaction(requires_new: true) { invitation.save! }
          return invitation
        rescue ActiveRecord::RecordInvalid
          raise DuplicateSecretDigest if invitation.errors.of_kind?(:secret_digest, :taken)
          raise InvalidSecretDigest if invitation.errors.any? { |error| error.attribute == :secret_digest }
          raise LocatorUnavailable unless invitation.errors.of_kind?(:locator, :taken) && attempts < MAX_LOCATOR_ATTEMPTS
        rescue ActiveRecord::RecordNotUnique
          raise DuplicateSecretDigest if exists?(secret_digest:)
          raise LocatorUnavailable if attempts >= MAX_LOCATOR_ATTEMPTS
        end
      end
    end
  end

  def pending?(now: Time.current)
    accepted_at.nil? && revoked_at.nil? && expires_at > now && grant.active?
  end
end
