# frozen_string_literal: true

require "digest"

class OwnerCeremony < ApplicationRecord
  BOOTSTRAP_LIFETIME = 10.minutes
  PURPOSES = %w[bootstrap recovery registration].freeze
  AUTHORITIES = %w[deployment owner_session].freeze
  DIGEST_FORMAT = /\A[0-9a-f]{64}\z/
  SECRET_FORMAT = /\A[A-Za-z0-9_-]{43}\z/

  class IssuanceRejected < StandardError
    def initialize = super("Owner ceremony issuance rejected")
  end

  belongs_to :owner, optional: true

  attr_readonly :owner_id, :purpose, :authority, :secret_digest, :expires_at

  validates :purpose, inclusion: { in: PURPOSES }
  validates :authority, inclusion: { in: AUTHORITIES }
  validates :secret_digest, presence: true, uniqueness: true, format: { with: DIGEST_FORMAT }
  validates :expires_at, presence: true

  def self.issue_bootstrap!(secret:, now: Time.current)
    raise IssuanceRejected unless secret.is_a?(String) && secret.match?(SECRET_FORMAT)

    transaction do
      raise IssuanceRejected if Owner.exists?

      create!(
        purpose: "bootstrap",
        authority: "deployment",
        secret_digest: Digest::SHA256.hexdigest(secret),
        expires_at: now + BOOTSTRAP_LIFETIME
      )
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    raise IssuanceRejected
  end

  def available_bootstrap?(now: Time.current)
    purpose == "bootstrap" && authority == "deployment" && owner_id.nil? &&
      consumed_at.nil? && expires_at > now
  end
end
