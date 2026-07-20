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

  attr_readonly :site_id, :number, :manifest_sha256, :finalized_at

  validates :number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :site_id }
  validates :manifest_sha256, presence: true, format: { with: Blob::SHA256_FORMAT }
  validates :finalized_at, presence: true
end
