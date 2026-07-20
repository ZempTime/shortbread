# frozen_string_literal: true

module Api
  module V1
    class ReleaseRollbacksController < BaseController
      required_scope "releases:rollback" if respond_to?(:required_scope, true)

      def create
        site = Site.find_by(slug: params[:site_slug])
        return render_error("site_not_found", :not_found) unless site

        result = ReleaseRollbacks.perform(
          site:,
          release_number: params[:number],
          idempotency_key: request.headers["Idempotency-Key"]
        )
        render json: { rollback: rollback_payload(result) },
          status: result.created ? :created : :ok
      rescue ReleaseRollbacks::IdempotencyKeyRequired
        render_error("idempotency_key_required", :unprocessable_entity)
      rescue ReleaseRollbacks::IdempotencyConflict
        render_error("idempotency_conflict", :conflict)
      rescue ReleaseRollbacks::ReleaseNotFound
        render_error("release_not_found", :not_found)
      rescue ReleaseRollbacks::NoCurrentRelease
        render_error("current_release_not_found", :conflict)
      end

      private

      def rollback_payload(result)
        rollback = result.rollback
        {
          id: rollback.id,
          site_slug: rollback.site.slug,
          from_release_number: result.from_release.number,
          to_release_number: result.to_release.number,
          resulting_release_number: result.to_release.number,
          changed: result.changed,
          recorded_at: rollback.created_at.iso8601(6)
        }
      end

      def render_error(code, status)
        render json: { error: { code: } }, status:
      end
    end
  end
end
