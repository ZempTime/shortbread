# frozen_string_literal: true

require "test_helper"

require "digest"
require "open3"
require "rbconfig"

class OwnerBootstrapTaskTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup { clear_owner_auth_records }
  teardown { clear_owner_auth_records }

  test "the deployment-only task reads a bootstrap secret from stdin and emits generic status" do
    secret = +"synthetic_#{"B" * 33}"
    digest = Digest::SHA256.hexdigest(secret)

    stdout, stderr, status = Open3.capture3(
      { "RAILS_ENV" => "test" },
      RbConfig.ruby,
      Rails.root.join("bin/rails").to_s,
      "shortbread:owner:issue_bootstrap",
      stdin_data: "#{secret}\n",
      chdir: Rails.root.to_s
    )

    assert status.success?, stderr
    assert_equal "Owner bootstrap ceremony issued.\n", stdout
    refute_includes stdout, secret
    refute_includes stderr, secret
    ceremony = OwnerCeremony.find_by!(secret_digest: digest)
    assert ceremony.available_bootstrap?
  ensure
    secret&.clear
  end

  private

  def clear_owner_auth_records
    OwnerCredential.delete_all
    OwnerCeremony.delete_all
    Owner.delete_all
  end
end
