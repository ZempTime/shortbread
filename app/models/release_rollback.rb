# frozen_string_literal: true

class ReleaseRollback < ApplicationRecord
  belongs_to :site
  belongs_to :from_release, class_name: "Release"
  belongs_to :to_release, class_name: "Release"

  attr_readonly :site_id, :from_release_id, :to_release_id, :idempotency_key_digest

  validates :idempotency_key_digest,
    presence: true,
    uniqueness: { scope: :site_id },
    format: { with: Blob::SHA256_FORMAT }
  validate :releases_belong_to_site

  private

  def releases_belong_to_site
    errors.add(:from_release, :invalid) if from_release && from_release.site_id != site_id
    errors.add(:to_release, :invalid) if to_release && to_release.site_id != site_id
  end
end
