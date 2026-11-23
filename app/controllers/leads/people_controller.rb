module Leads
  # The other people at a lead's business: who decides, who's keen, who else is involved. Each
  # becomes a contact of the client when it's won, and can be emailed from the lead.
  class PeopleController < ApplicationController
    allow_staff
    PERSON_PARAMS = { name: "string!", email: "string", phone: "string", title: "string", role: Person::ROLES.keys }.freeze
    agent_tool :add_lead_person, on: :create, title: "Add someone at a lead's business",
      description: "Someone besides the lead's own person: name, email, phone, title (their job), role (#{Person::ROLES.map { |key, label| "#{key}: #{label}" }.join(", ")}). They become a contact when the lead is won.",
      params: { person: PERSON_PARAMS }, next_tools: %i[show_lead]
    agent_tool :update_lead_person, on: :update, title: "Change someone at a lead's business",
      params: { person: PERSON_PARAMS.merge(name: "string") }, next_tools: %i[show_lead]
    agent_tool :remove_lead_person, on: :destroy, title: "Take someone off a lead"

    before_action :set_lead

    def create
      person = @lead.people.new(person_params)
      raise Lead::Refused, person.errors.full_messages.to_sentence unless person.save

      redirect_back fallback_location: lead_path(@lead), notice: "#{person.name} added."
    end

    def update
      person = @lead.people.find(params[:id])
      raise Lead::Refused, person.errors.full_messages.to_sentence unless person.update(person_params)

      redirect_back fallback_location: lead_path(@lead), notice: "#{person.name} saved."
    end

    def destroy
      person = @lead.people.find(params[:id])
      person.destroy!
      redirect_back fallback_location: lead_path(@lead), notice: "#{person.name} is off the lead."
    end

    private
      def person_params = params.expect(person: %i[name email phone title role])
  end
end
