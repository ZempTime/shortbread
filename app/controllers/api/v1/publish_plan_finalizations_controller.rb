# frozen_string_literal: true

module Api
  module V1
    class PublishPlanFinalizationsController < BaseController
      def create
        publish_plan = PublishPlan.find_by(id: params[:id])
        return render_error("publish_plan_not_found", :not_found) unless publish_plan

        result = Publishing.finalize(publish_plan:, blob_store: LocalBlobStore.new)
        release = result.release
        render json: {
          release: {
            id: release.id,
            site_slug: release.site.slug,
            number: release.number,
            manifest_sha256: release.manifest_sha256
          }
        }, status: result.created ? :created : :ok
      rescue Publishing::PublishIncomplete
        render_error("publish_incomplete", :conflict)
      rescue Publishing::PublishPlanExpired
        render_error("publish_plan_expired", :conflict)
      rescue Publishing::StalePublishPlan
        render_error("stale_publish_plan", :conflict)
      rescue Publishing::InconsistentPublishPlan
        render_error("inconsistent_publish_plan", :conflict)
      end

      private

      def render_error(code, status)
        render json: { error: { code: } }, status:
      end
    end
  end
end
