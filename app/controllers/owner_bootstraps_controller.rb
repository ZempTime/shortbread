# frozen_string_literal: true

class OwnerBootstrapsController < ApplicationController
  protect_from_forgery with: :exception

  rescue_from ActionController::InvalidAuthenticityToken, with: :not_found
  rescue_from ActionController::ParameterMissing, with: :not_found
  rescue_from OwnerRegistration::Rejected, with: :not_found
  rescue_from OwnerWebAuthn::InvalidConfiguration, with: :not_found

  def show
    return not_found unless apex_request? && !Owner.exists?

    set_private_headers
  rescue Shortbread::Hosts::InvalidHost
    not_found
  end

  def options
    webauthn = trusted_webauthn
    return not_found unless webauthn

    public_key = OwnerRegistration.options!(
      secret: params[:ceremony_secret],
      webauthn:
    )
    set_private_headers
    render json: { public_key: }
  end

  def create
    webauthn = trusted_webauthn
    return not_found unless webauthn

    registration = OwnerRegistration.complete!(
      secret: params[:ceremony_secret],
      label: params[:credential_label],
      public_key_credential: public_key_credential,
      webauthn:
    )
    set_private_headers
    render json: {
      owner: { id: registration.owner.id },
      redirect: "/owner"
    }, status: :created
  end

  private

  def apex_request?
    Shortbread::Hosts.parse(
      host: request.host,
      scheme: request.scheme,
      port: request.port
    ).kind == :apex
  end

  def trusted_webauthn
    webauthn = OwnerWebAuthn.configured
    host = Shortbread::Hosts.parse(
      host: request.host,
      scheme: request.scheme,
      port: request.port
    )
    return unless host.kind == :apex && host.apex_origin == webauthn.origin
    return unless request.headers["Origin"] == webauthn.origin
    return unless request.get_header("HTTP_SEC_FETCH_SITE") == "same-origin"
    return unless request.get_header("HTTP_SEC_FETCH_MODE") == "cors"
    return unless request.get_header("HTTP_SEC_FETCH_DEST") == "empty"

    webauthn
  rescue Shortbread::Hosts::InvalidHost
    nil
  end

  def public_key_credential
    credential = params.require(:public_key_credential)
    raise ActionController::ParameterMissing, :public_key_credential unless credential.respond_to?(:to_unsafe_h)

    credential.to_unsafe_h
  end

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
