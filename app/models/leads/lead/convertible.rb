# A lead that said yes becomes a client: the client (named for the lead's company, else the lead)
# and a contact for the lead, made through the core's own models, and the lead a customer pointing
# at that client. A client or contact that already exists is used rather than duplicated.
module Leads::Lead::Convertible
  extend ActiveSupport::Concern

  def converted? = client_id.present?

  # Returns the client.
  def convert_to_client!(user: Current.user)
    raise ArgumentError, "#{display_name} is already a client" if client

    transaction do
      contact = ::Contact.find_by(email: email)
      made = contact.nil? && ::Client.where(name: client_name).none?
      client = contact&.client || ::Client.find_or_create_by!(name: client_name)
      client.record_event!("client.created") if made
      client.contacts.create!(name: name.presence || email, email: email, phone: phone) unless contact

      update!(client: client)
      change_stage("customer", user: user)
      record_activity(:converted, summary: "Became a client: #{client.name}", data: { client_id: client.id }, user: user)
      client
    end
  end

  private
    def client_name = company.presence || name.presence || email
end
