# frozen_string_literal: true

module Api
  module V1
    class PublishPlansController < BaseController
      def create
        site = Site.find_by(slug: params[:site_slug])
        return render_error("site_not_found", :not_found) unless site

        result = Publishing.plan(
          site:,
          idempotency_key: request.headers["Idempotency-Key"],
          manifest: manifest_params
        )
        render json: { publish_plan: payload(result.publish_plan) },
          status: result.created ? :created : :ok
      rescue ActionController::ParameterMissing, Publishing::InvalidManifest
        render_error("invalid_manifest", :unprocessable_entity)
      rescue Publishing::IdempotencyKeyRequired
        render_error("idempotency_key_required", :unprocessable_entity)
      rescue Publishing::IdempotencyConflict
        render_error("idempotency_conflict", :conflict)
      end

      private

      def manifest_params
        params.require(:manifest).permit(entries: %i[path sha256 size content_type offline_policy]).to_h
      end

      def payload(publish_plan)
        {
          id: publish_plan.id,
          state: publish_plan.state,
          delta: Publishing.delta_for(publish_plan).counts,
          uploads: missing_entries(publish_plan).map { |entry| upload_payload(publish_plan, entry) },
          finalize_url: "/api/v1/publish-plans/#{publish_plan.id}/finalize"
        }
      end

      def missing_entries(publish_plan)
        blob_store = LocalBlobStore.new
        publish_plan.manifest.fetch("entries").uniq { |entry| entry.fetch("sha256") }.reject do |entry|
          blob = Blob.find_by(sha256: entry.fetch("sha256"))
          blob && blob.byte_size == entry.fetch("size") &&
            blob_store.verified?(storage_key: blob.storage_key, sha256: blob.sha256, byte_size: blob.byte_size)
        end
      end

      def upload_payload(publish_plan, entry)
        {
          sha256: entry.fetch("sha256"),
          size: entry.fetch("size"),
          method: "PUT",
          url: "/api/v1/publish-plans/#{publish_plan.id}/blobs/#{entry.fetch("sha256")}",
          headers: { "Content-Type" => "application/octet-stream" }
        }
      end

      def render_error(code, status)
        render json: { error: { code: } }, status:
      end
    end
  end
end
