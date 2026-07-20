# frozen_string_literal: true

class PublishPlan < ApplicationRecord
  STATES = %w[open finalized].freeze

  belongs_to :site
  belongs_to :base_release, class_name: "Release", optional: true
  belongs_to :release, optional: true

  attr_readonly :site_id, :base_release_id, :idempotency_key_digest, :manifest_sha256, :manifest, :expires_at

  validates :idempotency_key_digest,
    presence: true,
    uniqueness: { scope: :site_id },
    format: { with: Blob::SHA256_FORMAT }
  validates :manifest_sha256, presence: true, format: { with: Blob::SHA256_FORMAT }
  validates :manifest, presence: true
  validates :state, inclusion: { in: STATES }
  validates :expires_at, presence: true

  def open? = state == "open"
end
