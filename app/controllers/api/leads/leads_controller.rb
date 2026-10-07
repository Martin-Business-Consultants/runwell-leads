# frozen_string_literal: true

# The leads over the API.
#
#   GET    /api/leads            ?stage= ?q= ?page= ?per=
#   POST   /api/leads            creates the lead for `email`, or updates it (200)
#   GET    /api/leads/:id        with its activities, tasks and enrollments
#   PATCH  /api/leads/:id
#   DELETE /api/leads/:id        with everything it holds
module Api
  module Leads
    class LeadsController < ::Api::BaseController
      include PluginGated
      plugin :leads

      enforce_authorization
      requires_capability "leads:read", only: [:index, :show]
      requires_capability "leads:write", only: [:create, :update]
      requires_capability "leads:delete", only: :destroy

      before_action :set_lead, only: [:show, :update, :destroy]

      def index
        scope = ::Leads::Lead.includes(:owner).search_list(params[:q]).recent_first
        scope = scope.in_stage(params[:stage]) if params[:stage].present?

        @page_number = (params[:page] || 1).to_i.clamp(1, 10_000)
        @per = (params[:per] || 25).to_i.clamp(1, 100)
        @total = scope.count
        @leads = scope.offset((@page_number - 1) * @per).limit(@per)
      end

      def show
      end

      def create
        @lead = ::Leads::Lead.find_or_initialize_by(email: lead_params[:email].to_s.strip.downcase)

        if @lead.new_record?
          @lead.assign_attributes(lead_params.except(:stage).merge(source: "api", stage: lead_params[:stage].presence || "new"))
          @lead.save!
          @lead.record_creation
          render :show, status: :created
        elsif @lead.revise(lead_params.except(:email))
          render :show
        else
          render json: {error: "invalid", errors: @lead.errors.as_json}, status: :unprocessable_entity
        end
      end

      def update
        if @lead.revise(lead_params)
          render :show
        else
          render json: {error: "invalid", errors: @lead.errors.as_json}, status: :unprocessable_entity
        end
      end

      def destroy
        @lead.forget
        head :no_content
      end

      private

      def set_lead
        @lead = ::Leads::Lead.find(params[:id])
      end

      def lead_params
        params.require(:lead).permit(:email, :name, :phone, :company, :stage, :owner_id)
      end
    end
  end
end
