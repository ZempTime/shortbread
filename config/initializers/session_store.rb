# frozen_string_literal: true

require Rails.root.join("lib/shortbread/owner_session_cookie")

options = Shortbread::OwnerSessionCookie.options(production: Rails.env.production?)
Rails.application.config.session_store(:cookie_store, **options)
