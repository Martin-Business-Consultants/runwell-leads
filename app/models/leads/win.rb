module Leads
  # Winning a lead: the one place a lead reaches the core. Makes a client from it (or uses one
  # already on file, for more business from someone you work for), adds its person as that client's
  # contact unless they're on file already, and starts a first piece of work of the type picked, all
  # through the core's own models, so their events and rules are the usual ones. The lead keeps a
  # link to the client and its history stays here.
  class Win
    attr_reader :lead, :client, :contact, :work, :skipped

    def initialize(lead, by:, client_id: nil, client_name: nil, add_contact: true, work_label: nil, work_title: nil)
      @lead, @by = lead, by
      @client_id, @client_name = client_id.presence, client_name.to_s.squish.presence
      @add_contact = ActiveModel::Type::Boolean.new.cast(add_contact) != false
      @work_label, @work_title = work_label.presence, work_title.to_s.squish.presence
      @skipped = []
    end

    def call
      ApplicationRecord.transaction do
        @client = @client_id ? Client.find(@client_id) : Client.create!(name: @client_name || lead.company.presence || lead.display_name)
        add_contact if @add_contact
        start_work if @work_label
        lead.update_columns(state: "won", client_id: client.id, closed_at: Time.current, updated_at: Time.current)
        lead.log!("won", by: @by, data: { client: client.name, client_id: client.id, work: work&.title }.compact)
      end
      self
    rescue ActiveRecord::RecordInvalid => error
      raise Lead::Refused, error.record.errors.full_messages.to_sentence
    rescue ActiveRecord::RecordNotFound
      raise Lead::Refused, "That client isn’t on file."
    end

    # What was made, as one sentence for a notice.
    def summary
      made = [ "#{client.name} is a client#{" (already on file)" if @client_id}" ]
      made << "#{contact.name} is its contact" if contact
      made << "#{work.title} has started" if work
      made.to_sentence + "." + (skipped.any? ? " #{skipped.join(" ")}" : "")
    end

    private
      def add_contact
        if lead.email && (on_file = User.find_by(email_address: lead.email))
          @skipped << "#{on_file.display_name} is on file already with #{lead.email}, so no contact was added."
          return
        end
        name = lead.name.presence || lead.email
        return @skipped << "No name or email to add a contact by." unless name

        @contact = client.contacts.create!(name: name, email: lead.email, phone: lead.phone)
      end

      def start_work
        @work = Work.create!(client: client, label: @work_label, title: @work_title || lead.company.presence || client.name, created_by: @by)
      end
  end
end
