# frozen_string_literal: true

require "test_helper"

class OwnerAuthSchemaScopeTest < ActiveSupport::TestCase
  test "U02 installs only the first Owner bootstrap records" do
    assert ApplicationRecord.connection.data_source_exists?("owners")
    assert ApplicationRecord.connection.data_source_exists?("owner_credentials")
    assert ApplicationRecord.connection.data_source_exists?("owner_ceremonies")

    %w[api_tokens device_authorizations api_idempotency_records api_rate_limit_buckets].each do |future_table|
      refute ApplicationRecord.connection.data_source_exists?(future_table), "#{future_table} belongs to a later unit"
    end
  end
end
