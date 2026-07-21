# frozen_string_literal: true

secure = Rails.env.production?
key = secure ? "__Host-shortbread_apex" : "shortbread_apex"

Rails.application.config.session_store(
  :cookie_store,
  key:,
  secure:,
  httponly: true,
  same_site: :lax
)
