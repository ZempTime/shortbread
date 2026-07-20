# frozen_string_literal: true

module Api
  module V1
    class PeopleController < BaseController
      def create
        person = Person.new(person_params)

        if person.save
          render json: { person: { id: person.id, first_name: person.first_name } }, status: :created
        else
          render json: { error: { code: "invalid_person" } }, status: :unprocessable_entity
        end
      end

      private

      def person_params
        params.permit(:first_name)
      end
    end
  end
end
