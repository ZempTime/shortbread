# frozen_string_literal: true

module Api
  module V1
    class SitesController < BaseController
      def create
        site = Site.new(site_params)

        if site.save
          render json: { site: { id: site.id, slug: site.slug, name: site.name } }, status: :created
        elsif site.errors.of_kind?(:slug, :taken)
          render json: { error: { code: "site_exists" } }, status: :conflict
        else
          render json: { error: { code: "invalid_site" } }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotUnique
        render json: { error: { code: "site_exists" } }, status: :conflict
      end

      private

      def site_params
        params.permit(:slug, :name)
      end
    end
  end
end
