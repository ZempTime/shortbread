require "test_helper"

class HealthCheckTest < ActionDispatch::IntegrationTest
  test "application boots through its public health endpoint" do
    host! "localhost"
    get rails_health_check_path

    assert_response :success
  end
end
