# frozen_string_literal: true

class ReviewSurfacesController < ActionController::Base
  include SiteAuthenticated

  # Rails blocks non-XHR JavaScript responses so an embedded <script> on another site cannot read
  # per-user data out of them. This response carries no per-user data — it is the same static
  # module for every Viewer — and it is loaded by a <script> tag on the Site itself, which is
  # exactly the shape that check refuses. Access is still gated on a valid Grant-backed session.
  skip_forgery_protection

  def show
    return not_found unless authenticate_site!

    response.headers["Cache-Control"] = "no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    send_data ReviewSurface.script, type: "text/javascript; charset=utf-8", disposition: "inline"
  rescue SiteSession::Rejected, Shortbread::Hosts::InvalidHost,
    ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid
    not_found
  end
end
