module Leads
  class SequencesController < ApplicationController
    allow_staff
    require_permission :manage_sequences, except: %i[index show]
    agent_tool :list_lead_sequences, on: :index, title: "List lead email sequences", next_tools: %i[show_lead_sequence enroll_lead]
    agent_tool :show_lead_sequence, on: :show, title: "Show a lead email sequence", description: "Its emails in order, with their delays, and who is in it."
    agent_tool :create_lead_sequence, on: :create, title: "Add a lead email sequence",
      description: "Starts off; add its emails, then switch it on. trigger: manual (leads join by hand), captured (when a lead comes in from the website; trigger_source narrows it to one form's source) or stage (when a lead reaches trigger_stage).",
      params: { sequence: { name: "string!", trigger: Sequence::TRIGGERS.keys, trigger_source: "string", trigger_stage: Lead::STAGES, active: "boolean" } },
      next_tools: %i[add_lead_sequence_email]
    agent_tool :update_lead_sequence, on: :update, title: "Change a lead email sequence",
      description: "Switching it on (active) sends to everyone in it as their emails fall due.",
      params: { sequence: { name: "string", trigger: Sequence::TRIGGERS.keys, trigger_source: "string", trigger_stage: Lead::STAGES, active: "boolean" } },
      confirm: "Switching a sequence on emails the leads in it."
    agent_tool :delete_lead_sequence, on: :destroy, title: "Delete a lead email sequence",
      description: "Leads in it stop getting its emails; what was sent stays on their timelines."

    before_action :set_sequence, only: %i[show edit update destroy]

    def index
      @sequences = Sequence.ordered.includes(:steps)
      @counts = Enrollment.active.group(:sequence_id).count
    end

    def show
      @enrollments = @sequence.enrollments.active.includes(:lead).newest_first.limit(100)
    end

    def new
      @sequence = Sequence.new
    end

    def create
      @sequence = Sequence.new(sequence_params)
      if @sequence.save
        redirect_to leads_sequence_path(@sequence), notice: "#{@sequence.name} added. Add its emails, then switch it on."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @sequence.update(sequence_params)
        redirect_to leads_sequence_path(@sequence), notice: "#{@sequence.name} saved#{" and on" if @sequence.active?}."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @sequence.destroy!
      redirect_to leads_sequences_path, notice: "#{@sequence.name} deleted."
    end

    private
      def set_sequence = @sequence = Sequence.find(params[:id])
      def sequence_params = params.expect(sequence: %i[name trigger trigger_source trigger_stage active])
  end
end
