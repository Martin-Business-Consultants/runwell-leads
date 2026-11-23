module Leads
  # The email templates, in Settings › Plugins › Leads: a name, a subject and a body with {{fields}}
  # (Template::FIELDS), for the recap, the follow-up and the rest, so nobody writes them from nothing.
  class TemplatesController < ApplicationController
    allow_staff
    require_permission :manage_settings
    TEMPLATE_PARAMS = { name: "string!", subject: "string!", body: "text" }.freeze
    agent_tool :create_lead_template, on: :create, title: "Add an email template for leads",
      description: "name, subject and body (HTML or plain text). Fields filled in when it's used: #{Template::FIELDS.map { |key, label| "{{#{key}}} (#{label})" }.join(", ")}.",
      params: { template: TEMPLATE_PARAMS }, next_tools: %i[show_leads_settings]
    agent_tool :update_lead_template, on: :update, title: "Change an email template for leads",
      params: { template: TEMPLATE_PARAMS.transform_values { "string" }.merge(body: "text") }, next_tools: %i[show_leads_settings]
    agent_tool :delete_lead_template, on: :destroy, title: "Delete an email template for leads",
      description: "Plans and steps that started from it no longer do."

    def create
      template = Template.new(template_params)
      if template.save
        redirect_to leads_settings_path(anchor: "templates"), notice: "#{template.name} added."
      else
        redirect_to leads_settings_path(anchor: "templates"), alert: template.errors.full_messages.to_sentence
      end
    end

    def update
      template = Template.find(params[:id])
      if template.update(template_params)
        redirect_to leads_settings_path(anchor: "templates"), notice: "#{template.name} saved."
      else
        redirect_to leads_settings_path(anchor: "templates"), alert: template.errors.full_messages.to_sentence
      end
    end

    def destroy
      template = Template.find(params[:id])
      template.destroy!
      redirect_to leads_settings_path(anchor: "templates"), notice: "#{template.name} deleted."
    end

    private
      def template_params
        attributes = params.expect(template: %i[name subject body])
        body = attributes[:body]
        attributes[:body] = ActionController::Base.helpers.simple_format(body) if body.present? && !body.include?("<")
        attributes
      end
  end
end
