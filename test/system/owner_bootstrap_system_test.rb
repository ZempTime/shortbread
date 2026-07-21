# frozen_string_literal: true

require "application_system_test_case"

require "securerandom"
require "stringio"

class OwnerBootstrapSystemTest < ApplicationSystemTestCase
  setup do
    @previous_app_host = Capybara.app_host
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    @previous_rp_id = ENV["SHORTBREAD_OWNER_RP_ID"]
    @previous_origin = ENV["SHORTBREAD_OWNER_ORIGIN"]
    @ceremony_secret = SecureRandom.urlsafe_base64(32, false)
    ActionController::Base.allow_forgery_protection = true

    OwnerBootstrapCommand.call(
      input: StringIO.new("#{@ceremony_secret}\n"),
      output: StringIO.new
    )

    server = Capybara.current_session.server
    Capybara.app_host = "http://localhost:#{server.port}"
    ENV["SHORTBREAD_OWNER_RP_ID"] = "localhost"
    ENV["SHORTBREAD_OWNER_ORIGIN"] = Capybara.app_host
  end

  teardown do
    @authenticator&.remove!
    Capybara.app_host = @previous_app_host
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    ENV["SHORTBREAD_OWNER_RP_ID"] = @previous_rp_id
    ENV["SHORTBREAD_OWNER_ORIGIN"] = @previous_origin
    @ceremony_secret&.clear
  end

  test "Operator ceremony registers a real browser passkey into an authenticated Owner landing" do
    @authenticator = page.driver.browser.add_virtual_authenticator(
      Selenium::WebDriver::VirtualAuthenticatorOptions.new(
        protocol: :ctap2,
        transport: :internal,
        resident_key: true,
        user_verification: true,
        user_verified: true
      )
    )

    visit "/owner/bootstrap"
    assert_equal "true", find("#owner-bootstrap-form")["data-enhanced"]
    fill_in "Ceremony secret", with: @ceremony_secret
    fill_in "Passkey label", with: "Primary passkey"
    click_button "Register passkey"

    assert_current_path "/owner"
    refute_includes current_url, @ceremony_secret
    assert_text "Owner landing"
    assert_equal 1, Owner.count
    assert_equal "Primary passkey", Owner.sole.owner_credentials.sole.label
  end

  test "a rejected ceremony stays out of the URL and is cleared from the form" do
    rejected_secret = SecureRandom.urlsafe_base64(32, false)

    visit "/owner/bootstrap"
    fill_in "Ceremony secret", with: rejected_secret
    click_button "Register passkey"

    assert_current_path "/owner/bootstrap"
    refute_includes current_url, rejected_secret
    assert_field "Ceremony secret", with: ""
    assert_button "Register passkey", disabled: false
    assert_text "Owner registration could not be completed. Mint a fresh ceremony and try again."
    assert_equal 0, Owner.count
  ensure
    rejected_secret&.clear
  end
end
