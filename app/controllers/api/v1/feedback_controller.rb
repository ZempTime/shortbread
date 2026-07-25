# frozen_string_literal: true

module Api
  module V1
    class FeedbackController < BaseController
      required_scope "feedback:read" if respond_to?(:required_scope, true)

      def show
        site = Site.includes(:releases).find_by(slug: params[:site_slug])
        return render json: { error: { code: "site_not_found" } }, status: :not_found unless site

        render json: {
          site: { slug: site.slug },
          comments: SiteFeedback.call(site:)
        }
      end
    end
  end
end
