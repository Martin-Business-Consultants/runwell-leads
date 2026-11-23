module Leads
  # Logging what happened with a lead: a call, an email, a meeting or a note, and, in the same go,
  # what happens next and where it stands (next_step, next_step_on, stage_id), so after a call one
  # save does it all. Logged lines can be removed by whoever wrote them, or anyone who may delete.
  class ActivitiesController < ApplicationController
    allow_staff
    agent_tool :log_lead_activity, on: :create, title: "Log a call, email, meeting or note on a lead",
      description: "What happened, in the lead's history: kind call, email, meeting or note (default note), body what was said or agreed. " \
        "After a call, give stage_id if it moved on (which lays out that stage's plan), and the follow-ups agreed: next_step and next_step_on for one, or steps for several " \
        "(each title and due_on), added to its plan in the same call. Debrief a call this way: who, what they need, budget, timing, what was agreed, and who else is involved (add_lead_person).",
      params: { activity: { kind: Activity::LOGGED.keys, body: "text!", next_step: "string", next_step_on: "date", stage_id: "integer", steps: [ { title: "string!", due_on: "date" } ] } },
      next_tools: %i[show_lead add_lead_person]
    agent_tool :remove_lead_activity, on: :destroy, title: "Remove a logged call, email, meeting or note",
      description: "Only a line someone logged (not the changes the lead recorded itself), by whoever wrote it or someone who may delete records."

    before_action :set_lead

    def create
      attributes = params.expect(activity: [ :kind, :body, :next_step, :next_step_on, :stage_id, steps: [ [ :title, :due_on ] ] ])
      kind = attributes[:kind].presence_in(Activity::LOGGED.keys) || "note"
      follow_up = attributes.slice(:stage_id).to_h.select { |name, value| value.present? && @lead.public_send(name).to_s != value.to_s }
      planned = Array(attributes[:steps]).map { { title: it[:title], due_on: it[:due_on].presence } }.select { it[:title].present? }
      planned << { title: attributes[:next_step], due_on: attributes[:next_step_on].presence } if attributes[:next_step].present? || attributes[:next_step_on].present?
      raise Lead::Refused, "It’s #{@lead.state}: reopen it to move it." if follow_up.key?("stage_id") && !@lead.open?
      raise Lead::Refused, "It’s #{@lead.state}: reopen it to plan more." if planned.any? && !@lead.open?

      Lead.transaction do
        activity = @lead.activities.new(kind: kind, user: Current.user, body: attributes[:body])
        raise Lead::Refused, activity.errors.full_messages.to_sentence unless activity.save

        @lead.update_columns(last_activity_at: activity.created_at)
        @lead.update!(follow_up) if follow_up.any?
        planned.each { @lead.add_step!(**it) }
      end
      redirect_back fallback_location: lead_path(@lead), notice: "#{Activity::LOGGED[kind]} logged#{"; #{planned.size == 1 ? "a step" : "#{planned.size} steps"} planned" if planned.any?}."
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
