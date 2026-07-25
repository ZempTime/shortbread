# frozen_string_literal: true

class SiteContentsController < ActionController::Base
  include SiteAuthenticated

  def show
    return not_found unless authenticate_site!

    manifest_path = Shortbread::ManifestPaths.normalize(params[:path])
    return not_found unless manifest_path

    entry = current_entry(current_site, manifest_path)
    return not_found unless entry

    serve(entry)
  rescue Shortbread::Hosts::InvalidHost, SiteSession::Rejected,
    Shortbread::BlobStore::ContentMismatch, Shortbread::BlobStore::StorageFailure,
    ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid
    not_found
  end

  private

  def current_entry(site, manifest_path)
    release = site.current_release
    release&.manifest_entries&.includes(:blob)&.find_by(path: manifest_path)
  end

  def serve(entry)
    io = blob_store.open_verified(
      storage_key: entry.blob.storage_key,
      sha256: entry.blob.sha256,
      byte_size: entry.byte_size
    )
    response.headers["Content-Type"] = entry.content_type
    response.headers["Content-Length"] = entry.byte_size.to_s
    response.headers["ETag"] = %Q("#{entry.blob.sha256}")
    response.headers["Cache-Control"] = "no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.status = :ok
    self.response_body = request.head? ? [] : chunked_body(io)
    io = nil unless request.head?
  ensure
    io&.close
  end

  def chunked_body(io)
    Enumerator.new do |chunks|
      begin
        while (chunk = io.read(Shortbread::BlobStore::CHUNK_SIZE))
          chunks << chunk unless chunk.empty?
        end
      ensure
        io.close
      end
    end
  end

  def blob_store
    @blob_store ||= Shortbread::BlobStores.build
  end

  def not_found
    head :not_found
  end
end
