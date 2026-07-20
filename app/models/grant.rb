# frozen_string_literal: true

class Grant < ApplicationRecord
  belongs_to :site
  belongs_to :person
  has_many :invitations, dependent: :restrict_with_exception
  has_many :site_handoffs, dependent: :restrict_with_exception

  attr_readonly :site_id, :person_id

  validates :person_id, uniqueness: { scope: :site_id }

  scope :active, -> { where(revoked_at: nil) }

  def active? = revoked_at.nil?
end
