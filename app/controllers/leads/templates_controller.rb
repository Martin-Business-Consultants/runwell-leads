module Leads
  class TemplatesController < ApplicationController
    allow_staff
    require_permission :manage_sequences, except: :index
    agent_tool :list_lead_templates, on: :index, title: "List reply templates",
      description: "The team's email, text message and call templates for leads. kind: email, text or call.", params: { kind: Template::KINDS.keys }
    agent_tool :create_lead_template, on: :create, title: "Add a reply template",
      description: "kind: email, text or call. body is HTML and may say {{first_name}}, {{name}}, {{company}}, {{email}}, {{phone}}, {{my_name}} and {{business}}.",
      params: { template: { kind: Template::KINDS.keys, title: "string!", situation: "string", subject: "string", body: "text" } }
    agent_tool :update_lead_template, on: :update, title: "Change a reply template",
      params: { template: { kind: Template::KINDS.keys, title: "string", situation: "string", subject: "string", body: "text" } }
    agent_tool :delete_lead_template, on: :destroy, title: "Delete a reply template"

    before_action :set_template, only: %i[edit update destroy]

    def index
      Template.seed_defaults!
      @kind = params[:kind].presence_in(Template::KINDS.keys)
      @templates = (@kind ? Template.of_kind(@kind) : Template.all).ordered
    end

    def new
      @template = Template.new(kind: params[:kind].presence_in(Template::KINDS.keys) || "email")
    end

    def create
      @template = Template.new(template_params)
      if @template.save
        redirect_to leads_templates_path(kind: @template.kind), notice: "“#{@template.title}” added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @template.update(template_params)
        redirect_to leads_templates_path(kind: @template.kind), notice: "“#{@template.title}” saved."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @template.destroy!
      redirect_to leads_templates_path(kind: @template.kind), notice: "“#{@template.title}” deleted."
    end

    private
      def set_template = @template = Template.find(params[:id])
      def template_params = params.expect(template: %i[kind title situation subject body])
  end
end
