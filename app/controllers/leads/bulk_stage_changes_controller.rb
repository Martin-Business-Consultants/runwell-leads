# frozen_string_literal: true

# Leads: one stage for every ticked lead (the list's "Set to …" bulk action,
# which posts `status`, as every list's does).
module Leads
  class BulkStageChangesController < ::ApplicationController
    include PluginGated
    plugin :leads

    requires_capability "leads:write", only: :create

    def create
      stage = params[:status].to_s.presence_in(Lead::STAGES)

      if stage
        changed = Lead.change_stage_of(Lead.where(id: Array(params[:ids])).to_a, to: stage)
        redirect_to leads_path(request.query_parameters), notice: "#{changed.size} #{"lead".pluralize(changed.size)} set to #{stage}"
      else
        redirect_to leads_path, alert: "Pick a stage to set."
      end
    end
  end
end
