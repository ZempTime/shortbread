# frozen_string_literal: true

class SiteHandoff < ApplicationRecord
  DIGEST_FORMAT = /\A[0-9a-f]{64}\z/

  belongs_to :grant
  belongs_to :invitation

  attr_readonly :grant_id, :invitation_id, :audience, :nonce_digest, :expires_at

  validates :invitation_id, uniqueness: true
  validates :audience, presence: true, length: { maximum: Shortbread::Hosts::MAX_ORIGIN_BYTES }
  validates :nonce_digest, presence: true, uniqueness: true, format: { with: DIGEST_FORMAT }
  validates :expires_at, presence: true
  validate :invitation_belongs_to_grant

  private

  def invitation_belongs_to_grant
    return unless invitation && grant && invitation.grant_id != grant_id

    errors.add(:invitation, :invalid)
  end
end
