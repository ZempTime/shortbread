# frozen_string_literal: true

class Blob < ApplicationRecord
  SHA256_FORMAT = /\A[0-9a-f]{64}\z/

  has_many :manifest_entries, dependent: :restrict_with_exception

  attr_readonly :sha256, :byte_size, :storage_key

  validates :sha256, presence: true, uniqueness: true, format: { with: SHA256_FORMAT }
  validates :byte_size, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :storage_key, presence: true, uniqueness: true
end
