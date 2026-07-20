# frozen_string_literal: true

class OwnerCredential < ApplicationRecord
  TRANSPORTS = %w[ble hybrid internal nfc smart-card usb].freeze

  belongs_to :owner

  attr_readonly :owner_id, :credential_id, :public_key

  validates :credential_id, presence: true, uniqueness: true, length: { maximum: 1024 }
  validates :public_key, presence: true, length: { maximum: 16_384 }
  validates :sign_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :label, presence: true, length: { maximum: 100 }
  validate :transports_are_supported

  private

  def transports_are_supported
    return if transports.is_a?(Array) && transports.length <= TRANSPORTS.length &&
      transports.all? { |transport| TRANSPORTS.include?(transport) }

    errors.add(:transports, :invalid)
  end
end
