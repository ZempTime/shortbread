# frozen_string_literal: true

class CreatePeople < ActiveRecord::Migration[8.1]
  def change
    create_table :people do |t|
      t.string :first_name, null: false
      t.timestamps
    end
  end
end
