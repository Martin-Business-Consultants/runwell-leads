module Leads
  class CompletionsController < ApplicationController
    allow_staff
    agent_tool :complete_lead_task, on: :create, title: "Mark a lead follow-up done"
    agent_tool :reopen_lead_task, on: :destroy, title: "Reopen a lead follow-up"

    before_action { @task = Task.find(params[:task_id]) }

    def create
      @task.complete
      redirect_back fallback_location: lead_path(@task.lead), notice: "Done: #{@task.title}."
    end

    def destroy
      @task.reopen
      redirect_back fallback_location: lead_path(@task.lead), notice: "Reopened: #{@task.title}."
    end
  end
end
