module Leads
  # Winning a lead (Leads::Win): a page saying exactly what will be made (a client, or one on file,
  # its contact, a first piece of work of a type picked), then making it. Owners and managers
  # (win_leads), since it adds to the clients.
  class WinsController < ApplicationController
    allow_staff
    require_permission :win_leads
    agent_tool :win_lead, on: :create, title: "Win a lead, making it a client",
      description: "Closes an open lead as won and copies it to the clients: a new client named client_name (default: its company, else its name), " \
        "or client_id for one already on file (more business from someone you work for); its person added as the client's contact (add_contact, default true; " \
        "skipped if their email is on file already); and, with work_label (a type key from list_work_types), a first piece of work titled work_title. Owners and managers only.",
      params: { win: { client_name: "string", client_id: "integer", add_contact: "boolean", work_label: -> { WorkType.active_keys }, work_title: "string" } },
      next_tools: %i[show_client]

    before_action :set_lead

    def new
      raise Lead::Refused, "It’s #{@lead.state} already." unless @lead.open?

      @page_title = "Win #{@lead.display_name}"
      @match = Client.where("LOWER(name) = ?", (@lead.company || @lead.display_name).downcase).first
    end

    def create
      win = @lead.win!(**params.expect(win: %i[client_name client_id add_contact work_label work_title]).to_h.symbolize_keys)
      redirect_to (win.work ? main_app.work_path(win.work) : main_app.client_path(win.client)), notice: "Won. #{win.summary}"
    end
  end
end
