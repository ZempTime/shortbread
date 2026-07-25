# frozen_string_literal: true

class Comment < ApplicationRecord
  # The Anchor composite. Optional as a whole — a Site-level Comment carries no selection — and
  # all-or-nothing, so a half-recorded Anchor can never be stored.
  ANCHOR_ATTRIBUTES = %i[path quote prefix suffix start_offset].freeze

  belongs_to :site
  belongs_to :release
  belongs_to :person
  belongs_to :grant

  attr_readonly :site_id, :release_id, :person_id, :grant_id, :body,
    :path, :quote, :prefix, :suffix, :start_offset, :block_index, :block_offset

  scope :chronological, -> { order(:created_at, :id) }
  scope :anchored, -> { where.not(start_offset: nil) }

  validates :body, presence: true
  validates :start_offset, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :anchor_is_all_or_nothing
  validate :release_belongs_to_site

  def anchored? = start_offset.present?

  def to_anchor
    return nil unless anchored?

    Shortbread::Anchoring::Anchor.new(
      release_number: release.number, path:, quote:, prefix:, suffix:, start_offset:,
      block_index:, block_offset:
    )
  end

  private

  def anchor_is_all_or_nothing
    present = ANCHOR_ATTRIBUTES.reject { |attribute| public_send(attribute).nil? }
    return if present.empty? || present.length == ANCHOR_ATTRIBUTES.length

    (ANCHOR_ATTRIBUTES - present).each { |attribute| errors.add(attribute, :blank) }
  end

  def release_belongs_to_site
    return unless release && site_id && release.site_id != site_id

    errors.add(:release, :invalid)
  end
end
