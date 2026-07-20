# frozen_string_literal: true

class Owner < ApplicationRecord
  has_many :owner_credentials, dependent: :restrict_with_exception
  has_many :api_tokens, dependent: :restrict_with_exception

  validates :singleton_key, inclusion: { in: [ true ] }
  validates :webauthn_id, presence: true, uniqueness: true

  attr_readonly :singleton_key, :webauthn_id

  before_destroy { throw :abort }
end
