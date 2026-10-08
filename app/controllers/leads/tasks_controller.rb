module Leads
  class TasksController < ApplicationController
    allow_staff
    agent_tool :list_lead_tasks, on: :index, title: "List lead follow-ups",
      description: "Follow-up tasks on leads, overdue first. show: mine (the default), everyone, or done.",
      params: { show: %w[mine everyone done] }, next_tools: %i[complete_lead_task show_lead]
    agent_tool :add_lead_task, on: :create, title: "Add a follow-up to a lead",
      description: "Something to do about the lead, by a date. It goes to you unless assignee_id names someone; what's due shows on their home page.",
      params: { task: { title: "string!", due_on: "date", assignee_id: "integer" } }, next_tools: %i[list_lead_tasks]
    agent_tool :update_lead_task, on: :update, title: "Change a lead follow-up",
      params: { task: { title: "string", due_on: "date", assignee_id: "integer" } }
    agent_tool :delete_lead_task, on: :destroy, title: "Delete a lead follow-up"

    before_action :set_lead, only: :create
    before_action :set_task, only: %i[edit update destroy]

    def index
      @show = params[:show].presence_in(%w[mine everyone done]) || "mine"
      scope = case @show
      when "done" then Task.done.order(done_at: :desc).limit(200)
      when "everyone" then Task.pending.in_due_order
      else Task.pending.assigned_to(Current.user.person).in_due_order
      end
      @tasks = scope.includes(:lead, :assignee)
    end

    def create
      task = Task.assign(@lead, task_params)
      if task.persisted?
        redirect_to lead_path(@lead), notice: "Task added for #{task.assignee&.display_name || "nobody yet"}."
      else
        redirect_to lead_path(@lead), alert: task.errors.full_messages.to_sentence
      end
    end

    def edit
    end

    def update
      if @task.update(task_params)
        redirect_to lead_path(@task.lead), notice: "Task saved."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @task.destroy!
      redirect_back fallback_location: lead_path(@task.lead), notice: "Task deleted."
    end

    private
      def set_task = @task = Task.find(params[:id])
      def task_params = params.expect(task: %i[title due_on assignee_id])
  end
end
