# frozen_string_literal: true

# Leads: the ticked leads deleted, with their timelines, tasks and enrollments.
module Leads
  class BulkDeletionsController < ::ApplicationController
    include PluginGated
    plugin :leads

    requires_capability "leads:delete", only: :create

    def create
      leads = Lead.forget_all(Lead.where(id: Array(params[:ids])))
      redirect_to leads_path(request.query_parameters), notice: "#{leads.size} #{"lead".pluralize(leads.size)} deleted"
    end
  end
end
