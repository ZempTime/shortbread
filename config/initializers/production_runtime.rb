# frozen_string_literal: true

require "shortbread/production_runtime"

Shortbread::ProductionRuntime.new.validate! if Rails.env.production?
