module Leads
  # This morning's email, now, to whoever asks: to see what it says, or to catch up.
  class DigestsController < ApplicationController
    allow_staff
    agent_tool :send_leads_digest, on: :create, title: "Email me my leads' follow-ups now",
      description: "The morning email, sent now to your person: steps due today or late on their leads, leads going cold, and (for whoever's told about new leads) ones nobody has."

    def create
      DigestJob.perform_later(nil, Current.user.person.id)
      redirect_back fallback_location: leads_path, notice: "On its way to #{Current.user.person.email_address}."
    end
  end
end
