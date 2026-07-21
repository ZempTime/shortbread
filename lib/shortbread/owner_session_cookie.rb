# frozen_string_literal: true

module Shortbread
  module OwnerSessionCookie
    module_function

    def options(production:)
      {
        key: production ? "__Host-shortbread_apex" : "shortbread_apex",
        secure: !!production,
        httponly: true,
        path: "/",
        same_site: :lax,
        domain: nil
      }
    end
  end
end
