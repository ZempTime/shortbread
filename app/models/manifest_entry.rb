# frozen_string_literal: true

class ManifestEntry < ApplicationRecord
  OFFLINE_POLICIES = %w[required optional download].freeze

  belongs_to :release
  belongs_to :blob

  attr_readonly :release_id, :blob_id, :path, :byte_size, :content_type, :offline_policy

  validates :path, presence: true, uniqueness: { scope: :release_id }
  validates :byte_size, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :content_type, presence: true
  validates :offline_policy, inclusion: { in: OFFLINE_POLICIES }
end
