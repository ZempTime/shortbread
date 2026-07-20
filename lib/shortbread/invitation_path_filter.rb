# frozen_string_literal: true

module Shortbread
  module InvitationPathFilter
    INVITATION_ROUTE = %r{\A/invitations/[^/?]+}
    FILTERED_ROUTE_PREFIX = "/invitations/[FILTERED]"

    def filtered_path
      super.sub(INVITATION_ROUTE, FILTERED_ROUTE_PREFIX)
    end
  end
end
