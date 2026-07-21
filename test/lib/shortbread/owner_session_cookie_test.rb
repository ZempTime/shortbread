# frozen_string_literal: true

require "test_helper"

class Shortbread::OwnerSessionCookieTest < ActiveSupport::TestCase
  test "production apex sessions use an exact host-only Secure cookie contract" do
    assert_equal({
      key: "__Host-shortbread_apex",
      secure: true,
      httponly: true,
      path: "/",
      same_site: :lax,
      domain: nil
    }, Shortbread::OwnerSessionCookie.options(production: true))
  end

  test "local sessions keep the same host-only contract without a misleading prefix" do
    assert_equal({
      key: "shortbread_apex",
      secure: false,
      httponly: true,
      path: "/",
      same_site: :lax,
      domain: nil
    }, Shortbread::OwnerSessionCookie.options(production: false))
  end
end
