module Leads
  # Logging what happened with a lead: a call, an email, a meeting or a note, and, in the same go,
  # what happens next and where it stands (next_step, next_step_on, stage_id), so after a call one
  # save does it all. Logged lines can be removed by whoever wrote them, or anyone who may delete.
  class ActivitiesController < ApplicationController
    allow_staff
    agent_tool :log_lead_activity, on: :create, title: "Log a call, email, meeting or note on a lead",
      description: "What happened, in the lead's history: kind call, email, meeting or note (default note), body what was said or agreed. " \
        "After a call, give next_step (what happens next) and next_step_on (by when), and stage_id if it moved on, in the same call. Debrief a call this way: who, what they need, budget, timing, what was agreed.",
      params: { activity: { kind: Activity::LOGGED.keys, body: "text!", next_step: "string", next_step_on: "date", stage_id: "integer" } },
      next_tools: %i[show_lead]
    agent_tool :remove_lead_activity, on: :destroy, title: "Remove a logged call, email, meeting or note",
      description: "Only a line someone logged (not the changes the lead recorded itself), by whoever wrote it or someone who may delete records."

    before_action :set_lead

    def create
      attributes = params.expect(activity: %i[kind body next_step next_step_on stage_id])
      kind = attributes[:kind].presence_in(Activity::LOGGED.keys) || "note"
      follow_up = attributes.slice(:next_step, :next_step_on, :stage_id).to_h.select { |name, value| value.present? && @lead.public_send(name).to_s != value.to_s }
      raise Lead::Refused, "It’s #{@lead.state}: reopen it to move it." if follow_up.key?("stage_id") && !@lead.open?

      Lead.transaction do
        activity = @lead.activities.new(kind: kind, user: Current.user, body: attributes[:body])
        raise Lead::Refused, activity.errors.full_messages.to_sentence unless activity.save

        @lead.update_columns(last_activity_at: activity.created_at)
        @lead.update!(follow_up) if follow_up.any?
      end
      redirect_back fallback_location: lead_path(@lead), notice: "#{Activity::LOGGED[kind]} logged#{"; next step saved" if follow_up.key?("next_step") || follow_up.key?("next_step_on")}."
    rescue ActiveRecord::RecordInvalid => error
      raise Lead::Refused, error.record.errors.full_messages.to_sentence
    end

    def destroy
      activity = @lead.activities.find(params[:id])
      raise Lead::Refused, "Only a call, email, meeting or note can be removed, by whoever logged it or someone who may delete." unless activity.removable_by?(Current.user)

      activity.destroy!
      redirect_back fallback_location: lead_path(@lead), notice: "Removed."
    end
  end
end
