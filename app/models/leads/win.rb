module Leads
  # Winning a lead: the one place a lead reaches the core. Makes a client from it (or uses one
  # already on file, for more business from someone you work for), adds its person as that client's
  # contact unless they're on file already, and starts a first piece of work of the type picked, all
  # through the core's own models, so their events and rules are the usual ones. Since 3.1 everyone
  # else at the business (Leads::Person) becomes a contact too, its files become the client's
  # documents (kept from the portal), and an internal note on the client tells the story so far:
  # what they asked for, the calls and emails, its links. The lead keeps a link to the client and
  # its history stays here.
  class Win
    attr_reader :lead, :client, :contact, :contacts, :documents, :work, :skipped

    def initialize(lead, by:, client_id: nil, client_name: nil, add_contact: true, work_label: nil, work_title: nil)
      @lead, @by = lead, by
      @client_id, @client_name = client_id.presence, client_name.to_s.squish.presence
      @add_contact = ActiveModel::Type::Boolean.new.cast(add_contact) != false
      @work_label, @work_title = work_label.presence, work_title.to_s.squish.presence
      @skipped, @contacts, @documents = [], [], []
    end

    def call
      ApplicationRecord.transaction do
        @client = @client_id ? Client.find(@client_id) : Client.create!(name: @client_name || lead.company.presence || lead.display_name)
        if @add_contact
          add_contact
          add_people
        end
        start_work if @work_label
        carry_files
        tell_the_story
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
      people = ([ contact ] + contacts).compact
      made << "#{people.map(&:name).to_sentence} #{people.one? ? "is its contact" : "are its contacts"}" if people.any?
      made << "#{documents.size} #{documents.one? ? "file is" : "files are"} in its documents" if documents.any?
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

      # Everyone else at the business, as contacts, unless their email is on file already.
      def add_people
        emails = [ lead.email, contact&.email_address ].compact
        lead.people.each do |person|
          next if person.email && emails.include?(person.email)
          if person.email && (on_file = User.find_by(email_address: person.email))
            @skipped << "#{on_file.display_name} is on file already with #{person.email}."
            next
          end

          @contacts << client.contacts.create!(name: person.name, email: person.email, phone: person.phone, title: person.title)
          emails << person.email if person.email
        end
      end

      # Its files, as the client's documents, kept from the portal.
      def carry_files
        lead.attachments.includes(file_attachment: :blob).select { it.file.attached? }.each do |attachment|
          @documents << Document.create!(documentable: client, file: attachment.file.blob, uploaded_by: attachment.user || @by&.person, client_visible: false)
        end
      end

      # An internal note on the client: what they asked for, how it went, and its links.
      def tell_the_story
        logged = lead.activities.where(kind: Activity::LOGGED.keys).reorder(:created_at).includes(:user).last(15)
        links = lead.attachments.select(&:link?)
        return if lead.message.blank? && logged.empty? && links.empty?

        html = +"<p><strong>Won from a lead</strong>#{" (#{ERB::Util.h(lead.source)})" if lead.source}, after #{ERB::Util.h(time_since(lead.created_at))}.</p>"
        html << "<p><strong>What they asked for</strong></p>#{lead.message}" if lead.message.present?
        if links.any?
          html << "<p><strong>Links</strong></p><ul>"
          links.each { html << %(<li><a href="#{ERB::Util.h(it.url)}">#{ERB::Util.h(it.display_name)}</a></li>) }
          html << "</ul>"
        end
        logged.each do |activity|
          html << "<p><strong>#{Activity::LOGGED[activity.kind]}, #{activity.created_at.strftime("%b %-d")}#{", #{ERB::Util.h(activity.user.display_name)}" if activity.user}</strong></p>#{activity.body}"
        end
        client.notes.create!(body: html, author: @by&.person, kind: "internal", source: ::Current.source || "app")
      end

      def time_since(time)
        days = ((Time.current - time) / 1.day).round
        days < 1 ? "less than a day" : "#{days} #{days == 1 ? "day" : "days"}"
      end

      def start_work
        @work = Work.create!(client: client, label: @work_label, title: @work_title || lead.company.presence || client.name, created_by: @by)
      end
  end
end
