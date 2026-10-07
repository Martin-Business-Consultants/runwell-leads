# frozen_string_literal: true

# A sequence's emails as a lead would get them, one after another, filled
# in with a sample lead (or the one named by ?lead_id=).
module Leads
  class SequencePreviewsController < ::ApplicationController
    include PluginGated
    plugin :leads

    requires_capability "sequences:read", only: :show

    def show
      @sequence = Sequence.find(params[:sequence_id])
      @lead = Lead.find_by(id: params[:lead_id]) || Lead.new(name: "Jamie Rivera", email: "jamie@example.com", company: "Rivera & Co")
    end
  end
end
