# frozen_string_literal: true

require Rails.root.join("lib/shortbread/invitation_path_filter")

ActionDispatch::Request.prepend(Shortbread::InvitationPathFilter) unless
  ActionDispatch::Request < Shortbread::InvitationPathFilter
