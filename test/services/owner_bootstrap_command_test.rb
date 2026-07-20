# frozen_string_literal: true

require "test_helper"

require "digest"
require "stringio"

class OwnerBootstrapCommandTest < ActiveSupport::TestCase
  test "deployment authority issues a short-lived bootstrap ceremony from secret stdin without echoing it" do
    secret = +"synthetic_#{"A" * 33}"
    assert_equal 43, secret.bytesize
    output = StringIO.new
    now = Time.zone.local(2026, 7, 20, 10, 0, 0)

    ceremony = OwnerBootstrapCommand.call(
      input: StringIO.new("#{secret}\n"),
      output:,
      now:
    )

    assert_equal "bootstrap", ceremony.purpose
    assert_equal "deployment", ceremony.authority
    assert_equal Digest::SHA256.hexdigest(secret), ceremony.secret_digest
    assert_equal now + 10.minutes, ceremony.expires_at
    assert_nil ceremony.challenge
    assert_nil ceremony.consumed_at
    refute_includes output.string, secret
    refute_includes output.string, ceremony.secret_digest
    refute_match(%r{https?://}, output.string)
  ensure
    secret&.clear
  end
end
