# frozen_string_literal: true

module Api
  module V1
    class InvitationsController < BaseController
      def create
        grant = Grant.find_by(id: params[:grant_id])
        return render_error("grant_not_found", :not_found) unless grant

        invitation = Invitation.issue!(grant:, secret_digest: params[:secret_digest])
        render json: {
          invitation: {
            id: invitation.id,
            locator: invitation.locator,
            expires_at: invitation.expires_at.iso8601,
            status: "pending"
          }
        }, status: :created
      rescue Invitation::InvalidSecretDigest
        render_error("invalid_invitation_digest", :unprocessable_entity)
      rescue Invitation::DuplicateSecretDigest
        render_error("invitation_exists", :conflict)
      rescue Invitation::InactiveGrant
        render_error("grant_inactive", :conflict)
      rescue Invitation::LocatorUnavailable
        render_error("invitation_unavailable", :service_unavailable)
      end

      private

      def render_error(code, status)
        render json: { error: { code: } }, status:
      end
    end
  end
end
