# frozen_string_literal: true

class OwnerBootstrapsController < ApplicationController
  def show
    return not_found unless apex_request? && !Owner.exists?

    response.headers["Cache-Control"] = "no-store"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["X-Content-Type-Options"] = "nosniff"
  rescue Shortbread::Hosts::InvalidHost
    not_found
  end

  private

  def apex_request?
    Shortbread::Hosts.parse(
      host: request.host,
      scheme: request.scheme,
      port: request.port
    ).kind == :apex
  end

  def not_found
    head :not_found
  end
end
