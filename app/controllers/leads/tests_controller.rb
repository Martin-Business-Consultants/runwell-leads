module Leads
  class TestsController < ApplicationController
    require_permission :manage_sequences
    agent_tool :send_lead_sequence_test, on: :create, title: "Email yourself a lead sequence",
      description: "Every email of the sequence to you at once, as a lead with your name would get it."

    def create
      sequence = Sequence.find(params[:sequence_id])
      count = sequence.send_test(to: Current.user)
      redirect_to leads_sequence_path(sequence), notice: "Sent #{count} test #{"email".pluralize(count)} to #{Current.user.person.email_address}."
    end
  end
end
