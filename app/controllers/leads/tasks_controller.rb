# frozen_string_literal: true

# Tasks: the follow-ups across every lead — yours (the default), everyone's,
# or the done ones — overdue first. A task is added on its lead's page
# (POST /leads/:lead_id/tasks), edited here, and done or reopened through
# its completion.
module Leads
  class TasksController < ::ApplicationController
    include PluginGated
    plugin :leads

    requires_capability "tasks:read", only: :index
    requires_capability "tasks:write", only: [:create, :edit, :update, :destroy]

    before_action :set_task, only: [:edit, :update, :destroy]

    VIEWS = %w[mine all done].freeze

    def index
      @view = params[:view].presence_in(VIEWS) || "mine"
      @counts = {"mine" => Task.pending.assigned_to(Current.user).count, "all" => Task.pending.count, "done" => Task.done.count}
      @tasks = paginate(tasks_for(@view).includes(:lead, :assignee))
    end

    def create
      lead = Lead.find(params[:lead_id])
      task = Task.assign(lead, task_params)

      if task.persisted?
        redirect_to lead_path(lead, anchor: "tasks"), notice: "Task added"
      else
        redirect_to lead_path(lead, anchor: "tasks"), alert: task.errors.full_messages.to_sentence
      end
    end

    def edit
    end

    def update
      if @task.update(task_params)
        @task.track_event(:updated, title: @task.title, lead: @task.lead.email)
        redirect_to return_path, notice: "Task saved"
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @task.track_event(:deleted, title: @task.title, lead: @task.lead.email)
      @task.destroy!
      redirect_to return_path, notice: "Task deleted"
    end

    private

    def set_task
      @task = Task.find(params[:id])
    end

    def task_params
      params.require(:task).permit(:title, :due_on, :assignee_id)
    end

    def tasks_for(view)
      case view
      when "all" then Task.pending.in_due_order
      when "done" then Task.done.order(done_at: :desc)
      else Task.pending.assigned_to(Current.user).in_due_order
      end
    end

    # Back where the change was made: the lead's page or the Tasks list.
    def return_path
      params[:return_to] == "lead" ? lead_path(@task.lead, anchor: "tasks") : leads_tasks_path
    end
  end
end
