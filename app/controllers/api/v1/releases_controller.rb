# frozen_string_literal: true

module Api
  module V1
    class ReleasesController < BaseController
      DEFAULT_LIMIT = 50
      MAX_LIMIT = 100

      class InvalidPagination < StandardError; end

      required_scope "releases:read" if respond_to?(:required_scope, true)

      def index
        site = Site.find_by(slug: params[:site_slug])
        return render_error("site_not_found", :not_found) unless site

        limit = pagination_integer(:limit, default: DEFAULT_LIMIT, maximum: MAX_LIMIT)
        before = pagination_integer(:before, default: nil)
        scope = site.releases.includes(:manifest_entries).order(number: :desc)
        scope = scope.where("number < ?", before) if before
        page = scope.limit(limit + 1).to_a
        has_more = page.length > limit
        releases = page.first(limit)
        render json: {
          site: {
            slug: site.slug,
            current_release_number: site.current_release&.number
          },
          releases: releases.map { |release| release_payload(release, current: release == site.current_release) },
          pagination: {
            limit:,
            next_before: has_more ? releases.last.number : nil
          }
        }
      rescue InvalidPagination
        render_error("invalid_pagination", :unprocessable_entity)
      end

      private

      def release_payload(release, current:)
        entries = release.manifest_entries
        {
          id: release.id,
          number: release.number,
          manifest_sha256: release.manifest_sha256,
          finalized_at: release.finalized_at.iso8601(6),
          current:,
          files: entries.length,
          bytes: entries.sum(&:byte_size)
        }
      end

      def pagination_integer(name, default:, maximum: nil)
        raw = params[name]
        return default if raw.nil?

        value = Integer(raw, 10)
        valid = value.positive? && value.to_s == raw && (!maximum || value <= maximum)
        raise InvalidPagination unless valid

        value
      rescue ArgumentError
        raise InvalidPagination
      end

      def render_error(code, status)
        render json: { error: { code: } }, status:
      end
    end
  end
end
