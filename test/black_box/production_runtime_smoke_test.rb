# frozen_string_literal: true

require "test_helper"

require "open3"
require "rbconfig"

class ProductionRuntimeSmokeTest < ActiveSupport::TestCase
  test "one non-root candidate image boots every production process and its local dependencies" do
    skip "set SHORTBREAD_RUN_CONTAINER_SMOKE=1 to exercise the container runtime" unless
      ENV["SHORTBREAD_RUN_CONTAINER_SMOKE"] == "1"

    stdout, stderr, status = Open3.capture3(
      Rails.root.join("bin/production-smoke").to_s,
      chdir: Rails.root.to_s
    )

    assert status.success?, <<~MESSAGE
      production runtime smoke failed
      stdout:
      #{stdout}
      stderr:
      #{stderr}
    MESSAGE
    assert_includes stdout, "production runtime smoke: green"
  end
end
