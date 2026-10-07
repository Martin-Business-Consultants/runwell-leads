# frozen_string_literal: true

# A task done (POST) or reopened (DELETE).
module Leads
  class TaskCompletionsController < ::ApplicationController
    include PluginGated
    plugin :leads

    requires_capability "tasks:write", only: [:create, :destroy]

    before_action { @task = Task.find(params[:task_id]) }

    def create
      @task.complete
      redirect_back_or_to leads_tasks_path, notice: "Done: #{@task.title}"
    end

    def destroy
      @task.reopen
      redirect_back_or_to leads_tasks_path, notice: "Reopened: #{@task.title}"
    end
  end
end
