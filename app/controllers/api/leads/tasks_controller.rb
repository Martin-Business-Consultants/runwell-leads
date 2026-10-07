# frozen_string_literal: true

# Tasks over the API.
#
#   GET  /api/leads/tasks              open tasks across every lead, overdue
#                                      first (?assignee=me, ?overdue=1, ?done=1)
#   GET  /api/leads/:lead_id/tasks     one lead's
#   POST /api/leads/:lead_id/tasks     {task: {title:, due_on:, assignee_id:}}
module Api
  module Leads
    class TasksController < ::Api::BaseController
      include PluginGated
      plugin :leads

      enforce_authorization
      requires_capability "tasks:read", only: :index
      requires_capability "tasks:write", only: :create

      def index
        scope = params[:lead_id] ? ::Leads::Lead.find(params[:lead_id]).tasks : ::Leads::Task.all
        scope = params[:done].present? ? scope.done.order(done_at: :desc) : scope.pending.in_due_order
        scope = scope.assigned_to(Current.user) if params[:assignee] == "me"
        scope = scope.overdue if params[:overdue].present?
        @tasks = scope.includes(:lead, :assignee).limit(200)
      end

      def create
        lead = ::Leads::Lead.find(params[:lead_id])
        @task = ::Leads::Task.assign(lead, params.require(:task).permit(:title, :due_on, :assignee_id))

        if @task.persisted?
          render "api/leads/tasks/show", status: :created
        else
          render json: {error: "invalid", errors: @task.errors.as_json}, status: :unprocessable_entity
        end
      end
    end
  end
end
