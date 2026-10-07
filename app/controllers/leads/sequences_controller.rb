# frozen_string_literal: true

# Sequences: the list, and the editor — its name, trigger and whether it
# sends, and its steps as one list of rows (Leads::Sequence::Stepped).
module Leads
  class SequencesController < ::ApplicationController
    include PluginGated
    plugin :leads

    requires_capability "sequences:read", only: [:index, :edit]
    requires_capability "sequences:write", only: [:new, :create, :update, :destroy]

    before_action :set_sequence, only: [:edit, :update, :destroy]

    def index
      @sequences = Sequence.ordered.includes(:steps)
      @active_counts = Enrollment.active.group(:sequence_id).count
      @total_counts = Enrollment.group(:sequence_id).count
    end

    def new
      @sequence = Sequence.new(active: false, trigger: "manual")
      @sequence.steps.build(position: 0, delay_amount: 0, delay_unit: "hours", subject: "", body: "")
    end

    def create
      @sequence = Sequence.new

      if @sequence.save_with_steps(sequence_params, step_rows)
        @sequence.track_event(:created, name: @sequence.name)
        redirect_to edit_leads_sequence_path(@sequence), notice: "Sequence created"
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @sequence.save_with_steps(sequence_params, step_rows)
        @sequence.track_event(:updated, name: @sequence.name)
        redirect_to edit_leads_sequence_path(@sequence), notice: "Sequence saved"
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @sequence.remove
      redirect_to leads_sequences_path, notice: "#{@sequence.name} deleted"
    end

    private

    def set_sequence
      @sequence = Sequence.find(params[:id])
    end

    def sequence_params
      params.require(:sequence).permit(:name, :active, :trigger, :trigger_form_id, :trigger_stage)
    end

    def step_rows
      Sequence.step_rows(params.dig(:sequence, :steps) || {})
    end
  end
end
