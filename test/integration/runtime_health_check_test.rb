# frozen_string_literal: true

require "test_helper"

require "tmpdir"

class RuntimeHealthCheckTest < ActionDispatch::IntegrationTest
  test "liveness reports a booted process without claiming dependency readiness" do
    host! "localhost"
    get "/health/live"

    assert_response :success
  end

  test "readiness requires primary database, queue database, and writable private Blob storage" do
    Dir.mktmpdir("shortbread-health") do |blob_root|
      with_blob_root(blob_root) do
        host! "localhost"
        get "/health/ready"

        assert_response :success
        assert_equal(
          { "status" => "ready", "dependencies" => %w[database queue private_blob] },
          response.parsed_body
        )
        assert_empty Dir.children(blob_root)
      end
    end
  end

  test "readiness fails closed when private Blob storage is unavailable" do
    Dir.mktmpdir("shortbread-health") do |directory|
      with_blob_root(File.join(directory, "missing")) do
        host! "localhost"
        get "/health/ready"

        assert_response :service_unavailable
        assert_equal({ "status" => "not_ready" }, response.parsed_body)
      end
    end
  end

  test "readiness fails closed and cleans up when private Blob hard-link creation fails" do
    Dir.mktmpdir("shortbread-health") do |blob_root|
      with_blob_root(blob_root) do
        File.stub(:link, ->(*) { raise Errno::EPERM }) do
          host! "localhost"
          get "/health/ready"
        end

        assert_response :service_unavailable
        assert_equal({ "status" => "not_ready" }, response.parsed_body)
        assert_empty Dir.children(blob_root)
      end
    end
  end

  private

  def with_blob_root(root)
    previous = ENV["SHORTBREAD_BLOB_ROOT"]
    ENV["SHORTBREAD_BLOB_ROOT"] = root
    yield
  ensure
    ENV["SHORTBREAD_BLOB_ROOT"] = previous
  end
end
