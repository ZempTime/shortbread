# frozen_string_literal: true

namespace :shortbread do
  namespace :owner do
    desc "Issue the one-use Owner bootstrap ceremony from a secret read through stdin"
    task issue_bootstrap: :environment do
      OwnerBootstrapCommand.call(input: $stdin, output: $stdout)
    rescue OwnerBootstrapCommand::Rejected
      abort "Owner bootstrap ceremony was not issued."
    end
  end
end
