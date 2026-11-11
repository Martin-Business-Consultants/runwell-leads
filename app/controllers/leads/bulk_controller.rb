module Leads
  # Leads, many at once, from the table's bulk bar or an agent: give them to someone, move them to a
  # stage, lose them (spam, say), or delete them. Each goes through the lead's own rules, one at a
  # time; one a change doesn't apply to (closed, say) is skipped and named.
  class BulkController < ApplicationController
    allow_staff
    require_permission :delete_records, only: :destroy
    agent_tool :bulk_update_leads, on: :update, title: "Change several leads at once",
      description: "ids: the leads. Then one of: lead[owner_id] (me, someone's id or name, or nobody), lead[stage_id] (open leads only), " \
        "or lead[lost_reason] to lose them (#{Lead::LOST_REASONS.keys.join(", ")}). Closed leads are skipped for stage and loss.",
      params: { ids: "integer[]!", lead: { owner_id: "string", stage_id: "integer", lost_reason: Lead::LOST_REASONS.keys } }
    agent_tool :bulk_delete_leads, on: :destroy, title: "Delete several leads at once",
      description: "Gone for good, with their history. To keep them, lose them instead.", params: { ids: "integer[]!" }

    MAX = 500

    def update
      change = params.expect(lead: %i[owner_id stage_id lost_reason])
      if change.key?(:owner_id)
        owner = owner_from(change[:owner_id])
        raise Lead::Refused, "Nobody on the team matches “#{change[:owner_id]}”." if owner.nil? && change[:owner_id].present? && change[:owner_id] != "nobody"

        apply("Gave %{count} to #{owner&.display_name || "nobody"}") { it.update(owner: owner) || it.errors.full_messages.to_sentence }
      elsif change[:stage_id].present?
        stage = Stage.find(change[:stage_id])
        apply("Moved %{count} to #{stage.name}") { it.move_to!(stage); true }
      elsif change[:lost_reason].present?
        apply("Lost %{count}: #{Lead::LOST_REASONS[change[:lost_reason]]&.downcase}") { it.lose!(reason: change[:lost_reason]); true }
      else
        redirect_back fallback_location: leads_path, alert: "Say what to change."
      end
    end

    def destroy
      apply("Deleted %{count}") { it.destroy ? true : "it couldn’t be deleted" }
    end

    private
      def selected
        ids = Array(params[:ids]).flat_map { it.to_s.split(",") }.map(&:to_i).select(&:positive?).uniq.first(MAX)
        Lead.where(id: ids).to_a
      end

      # Runs the change on each lead: true when it worked, else why not; refusals are named.
      def apply(done)
        leads = selected
        return redirect_back(fallback_location: leads_path, alert: "Select at least one first.") if leads.empty?

        skipped = []
        changed = leads.count do |lead|
          result = begin
            yield(lead)
          rescue Lead::Refused => error
            error.message
          end
          result == true ? true : (skipped << "#{lead.display_name} (#{result.to_s.sub(/\.\z/, "")})" and false)
        end
        message = format(done, count: "#{changed} #{changed == 1 ? "lead" : "leads"}") + "."
        message += " Skipped #{skipped.to_sentence}." if skipped.any?
        redirect_back fallback_location: leads_path, (changed.zero? ? :alert : :notice) => message
      end
  end
end
