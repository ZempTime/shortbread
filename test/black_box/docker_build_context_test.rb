# frozen_string_literal: true

require "test_helper"

class DockerBuildContextTest < ActiveSupport::TestCase
  LOCAL_CREDENTIAL_OR_CONFIG = /(?:
    \.bundle|
    \/config\/.*(?:\.key|credentials.*\.yml\.enc)|
    fnox|
    mise\.local|
    credentials\.local|
    secrets\.local
  )/x

  test "Docker excludes every local credential and configuration path ignored by Git" do
    git_patterns = ignore_patterns(".gitignore").grep(LOCAL_CREDENTIAL_OR_CONFIG)
    docker_patterns = ignore_patterns(".dockerignore")

    missing_patterns = git_patterns.reject do |pattern|
      docker_patterns.include?(pattern.delete_prefix("/"))
    end

    assert_empty missing_patterns, <<~MESSAGE
      Add every Git-ignored local credential/config pattern to .dockerignore.
      Missing: #{missing_patterns.join(', ')}
    MESSAGE
  end

  private

  def ignore_patterns(path)
    Rails.root.join(path).read.lines(chomp: true).reject do |line|
      line.empty? || line.start_with?("#", "!")
    end
  end
end
