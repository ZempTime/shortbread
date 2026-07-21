# frozen_string_literal: true

class RuntimeHealthChecksController < ActionController::API
  def ready
    ActiveRecord::Base.connection.select_value("SELECT 1")
    SolidQueue::Record.connection.select_value("SELECT 1")
    raise Errno::ENOENT unless private_blob_ready?

    render json: { status: "ready", dependencies: %w[database queue private_blob] }
  rescue StandardError
    render json: { status: "not_ready" }, status: :service_unavailable
  end

  private

  def private_blob_ready?
    root = ENV.fetch("SHORTBREAD_BLOB_ROOT", Rails.root.join("tmp", "blob-store"))
    Shortbread::PrivateBlobReadiness.ready?(root)
  end
end
