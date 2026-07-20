# frozen_string_literal: true

class SiteContentsController < ActionController::Base
  def show
    host = Shortbread::Hosts.parse(host: request.host, scheme: request.scheme, port: request.port)
    return not_found unless host.kind == :site

    site = Site.find_by(slug: host.site_slug)
    return not_found unless site

    authenticate!(host:, site:)
    entry = current_index(site)
    return not_found unless entry

    serve(entry)
  rescue Shortbread::Hosts::InvalidHost, SiteSession::Rejected,
    LocalBlobStore::ContentMismatch, LocalBlobStore::StorageFailure
    not_found
  end

  private

  def authenticate!(host:, site:)
    secure = request.ssl?
    SiteSession.authenticate(
      token: cookies[SiteSession.cookie_name(secure:)],
      audience: host.site_origin,
      site:,
      now: Time.current
    )
  end

  def current_index(site)
    release = site.current_release
    release&.manifest_entries&.includes(:blob)&.find_by(path: "index.html")
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
        while (chunk = io.read(LocalBlobStore::CHUNK_SIZE))
          chunks << chunk unless chunk.empty?
        end
      ensure
        io.close
      end
    end
  end

  def blob_store
    @blob_store ||= LocalBlobStore.new
  end

  def not_found
    head :not_found
  end
end
