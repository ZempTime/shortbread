# frozen_string_literal: true

require "io/console"

class OwnerBootstrapCommand
  class Rejected < StandardError
    def initialize = super("Owner bootstrap command rejected")
  end

  def self.call(input:, output:, now: Time.current)
    new(input:, output:).call(now:)
  rescue OwnerCeremony::IssuanceRejected
    raise Rejected
  end

  def initialize(input:, output:)
    @input = input
    @output = output
  end

  def call(now:)
    secret = read_secret
    ceremony = OwnerCeremony.issue_bootstrap!(secret:, now:)
    output.puts "Owner bootstrap ceremony issued."
    ceremony
  ensure
    secret&.clear
  end

  private

  attr_reader :input, :output

  def read_secret
    value = if input.respond_to?(:tty?) && input.tty? && input.respond_to?(:noecho)
      input.noecho(&:gets)
    else
      input.gets
    end
    secret = value&.chomp
    raise Rejected unless secret&.match?(OwnerCeremony::SECRET_FORMAT)

    secret
  end
end
