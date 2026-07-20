# frozen_string_literal: true

module Api
  module V1
    class PublishPlanBlobsController < BaseController
      def update
        publish_plan = PublishPlan.find_by(id: params[:publish_plan_id])
        return render_error("publish_plan_not_found", :not_found) unless publish_plan
        return render_error("publish_plan_expired", :conflict) unless publish_plan.open? && publish_plan.expires_at.future?

        entry = publish_plan.manifest.fetch("entries").find { |item| item.fetch("sha256") == params[:sha256] }
        return render_error("blob_not_expected", :not_found) unless entry

        storage_key = blob_store.put_verified(
          io: request.body,
          sha256: entry.fetch("sha256"),
          byte_size: entry.fetch("size")
        )
        persist_blob!(entry:, storage_key:)
        head :no_content
      rescue LocalBlobStore::ContentMismatch
        render_error("blob_content_mismatch", :unprocessable_entity)
      rescue LocalBlobStore::StorageFailure
        render_error("blob_storage_failed", :service_unavailable)
      end

      private

      def blob_store
        @blob_store ||= LocalBlobStore.new
      end

      def persist_blob!(entry:, storage_key:)
        Blob.create!(
          sha256: entry.fetch("sha256"),
          byte_size: entry.fetch("size"),
          storage_key:
        )
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        blob = Blob.find_by(sha256: entry.fetch("sha256"))
        expected = blob && blob.byte_size == entry.fetch("size") && blob.storage_key == storage_key
        raise LocalBlobStore::StorageFailure unless expected
      end

      def render_error(code, status)
        render json: { error: { code: } }, status:
      end
    end
  end
end
