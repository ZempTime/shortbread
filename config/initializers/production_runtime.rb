# frozen_string_literal: true

require "shortbread/production_runtime"

if Rails.env.production?
  Shortbread::ProductionRuntime.new(role: ENV.fetch("SHORTBREAD_PROCESS_ROLE", "web")).validate!
end
