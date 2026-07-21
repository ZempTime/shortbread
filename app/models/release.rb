# frozen_string_literal: true

class Release < ApplicationRecord
  belongs_to :site
  has_many :manifest_entries, dependent: :restrict_with_exception
  has_many :rollbacks_from,
    class_name: "ReleaseRollback",
    foreign_key: :from_release_id,
    dependent: :restrict_with_exception,
    inverse_of: :from_release
  has_many :rollbacks_to,
    class_name: "ReleaseRollback",
    foreign_key: :to_release_id,
    dependent: :restrict_with_exception,
    inverse_of: :to_release

  attr_readonly :site_id, :number, :manifest_sha256

  scope :published, -> {
    joins("INNER JOIN publish_plans ON publish_plans.release_id = releases.id")
      .where.not(releases: { finalized_at: nil })
      .where.not(publish_plans: { finalized_at: nil })
      .where(publish_plans: { state: "finalized" })
      .where("publish_plans.site_id = releases.site_id")
      .where("publish_plans.manifest_sha256 = releases.manifest_sha256")
  }

  validates :number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :site_id }
  validates :manifest_sha256, presence: true, format: { with: Blob::SHA256_FORMAT }
  validates :finalized_at, presence: true, on: :update
end
