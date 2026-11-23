module Leads
  # Files and links kept on a lead: the proposal, a deck, a Google Doc. Files become the client's
  # documents when it's won; links go into the note that tells its story.
  class AttachmentsController < ApplicationController
    allow_staff
    agent_tool :add_lead_file, on: :create, title: "Add a file or link to a lead",
      description: "A link (url, e.g. a Google Doc or a proposal) or a file, with an optional name. Files go to the client's documents when the lead is won.",
      params: { attachment: { url: "string", file: "file", name: "string" } }, next_tools: %i[show_lead]
    agent_tool :remove_lead_file, on: :destroy, title: "Remove a file or link from a lead",
      description: "By whoever added it, or someone who may delete records."

    before_action :set_lead

    def create
      attachment = @lead.attachments.new(params.expect(attachment: %i[url file name]).merge(user: Current.user.person))
      raise Lead::Refused, attachment.errors.full_messages.to_sentence unless attachment.save

      @lead.log!("file", data: { name: attachment.display_name })
      redirect_back fallback_location: lead_path(@lead), notice: "#{attachment.display_name} added."
    end

    def destroy
      attachment = @lead.attachments.find(params[:id])
      raise Lead::Refused, "Only whoever added it, or someone who may delete, can remove it." unless attachment.removable_by?(Current.user)

      attachment.destroy!
      redirect_back fallback_location: lead_path(@lead), notice: "#{attachment.display_name} removed."
    end
  end
end
