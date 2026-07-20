# frozen_string_literal: true

class Release < ApplicationRecord
  belongs_to :site
  has_many :manifest_entries, dependent: :restrict_with_exception

  attr_readonly :site_id, :number, :manifest_sha256, :finalized_at

  validates :number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :site_id }
  validates :manifest_sha256, presence: true, format: { with: Blob::SHA256_FORMAT }
  validates :finalized_at, presence: true
end
