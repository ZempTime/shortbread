# frozen_string_literal: true

module Shortbread
  module RackResponses
    NOT_FOUND_HEADERS = {
      "content-type" => "text/plain; charset=utf-8",
      "content-length" => "0"
    }.freeze
    private_constant :NOT_FOUND_HEADERS

    def self.not_found
      [ 404, NOT_FOUND_HEADERS.dup, [] ]
    end
  end
end
