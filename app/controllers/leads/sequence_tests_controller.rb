# frozen_string_literal: true

# "Send test": every step of a sequence to the person asking (Leads::Sequence::Testable).
module Leads
  class SequenceTestsController < ::ApplicationController
    include PluginGated
    plugin :leads

    requires_capability "sequences:write", only: :create

    def create
      sequence = Sequence.find(params[:sequence_id])
      count = sequence.send_test(to: Current.user)
      redirect_to edit_leads_sequence_path(sequence), notice: "Sent #{count} test #{"email".pluralize(count)} to #{Current.user.email}"
    end
  end
end
