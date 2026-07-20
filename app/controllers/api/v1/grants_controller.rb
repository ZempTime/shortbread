# frozen_string_literal: true

module Api
  module V1
    class GrantsController < BaseController
      def create
        site = Site.find_by(slug: params[:site_slug])
        return render_not_found("site_not_found") unless site

        person = Person.find_by(id: params[:person_id])
        return render_not_found("person_not_found") unless person

        grant = Grant.new(site:, person:)
        if grant.save
          render json: { grant: grant_payload(grant) }, status: :created
        elsif grant.errors.of_kind?(:person_id, :taken)
          render_conflict
        else
          render json: { error: { code: "invalid_grant" } }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotUnique
        render_conflict
      end

      private

      def grant_payload(grant)
        {
          id: grant.id,
          site_slug: grant.site.slug,
          person_id: grant.person_id,
          offline_allowed: grant.offline_allowed
        }
      end

      def render_not_found(code)
        render json: { error: { code: } }, status: :not_found
      end

      def render_conflict
        render json: { error: { code: "grant_exists" } }, status: :conflict
      end
    end
  end
end
