# frozen_string_literal: true

class Person < ApplicationRecord
  has_many :grants, dependent: :restrict_with_exception

  validates :first_name, presence: true
end
