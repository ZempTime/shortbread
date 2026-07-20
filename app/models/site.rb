# frozen_string_literal: true

class Site < ApplicationRecord
  SLUG_FORMAT = /\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z/

  belongs_to :current_release, class_name: "Release", optional: true
  has_many :grants, dependent: :restrict_with_exception
  has_many :releases, dependent: :restrict_with_exception
  has_many :publish_plans, dependent: :restrict_with_exception

  attr_readonly :slug

  validates :slug, presence: true, uniqueness: true, format: { with: SLUG_FORMAT }
  validates :name, presence: true
  validate :slug_fits_configured_site_hostname
  validate :current_release_belongs_to_site

  private

  def slug_fits_configured_site_hostname
    errors.add(:slug, :invalid) unless Shortbread::Hosts.valid_site_hostname?(slug:)
  end

  def current_release_belongs_to_site
    return unless current_release && current_release.site_id != id

    errors.add(:current_release, :invalid)
  end
end
