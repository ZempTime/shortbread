# frozen_string_literal: true

class OwnerLandingsController < ApplicationController
  layout false

  def show
    host = Shortbread::Hosts.parse(
      host: request.host,
      scheme: request.scheme,
      port: request.port
    )
    return not_found unless host.kind == :apex
    return not_found unless Owner.find_by(id: session[:owner_id]) == Owner.sole

    set_private_headers
  rescue ActiveRecord::RecordNotFound, Shortbread::Hosts::InvalidHost
    not_found
  end

  private

  def set_private_headers
    response.headers["Cache-Control"] = "no-store"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["X-Content-Type-Options"] = "nosniff"
  end

  def not_found
    set_private_headers
    head :not_found
  end
end
