# frozen_string_literal: true

# An API controller nested under a lead (/api/leads/:lead_id/…) loads it here;
# an unknown lead is the base controller's 404.
module Api::Leads::LeadScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_lead
  end

  private

  def set_lead
    @lead = ::Leads::Lead.find(params[:lead_id])
  end
end
