module Leads
  # Writing to a lead from its page: to its person or anyone else there, from a template if picked
  # (or the one its step starts from), edited, then sent from the install's address under the
  # writer's name, with replies to the writer and a copy in their inbox. It goes in the lead's
  # history as an email (so it counts as being in touch), and sending it for a step ticks it off.
  class EmailsController < ApplicationController
    allow_staff
    agent_tool :send_lead_email, on: :create, title: "Email a lead",
      description: "Sends an email to the lead (to: their address, or others at their business; default their own) from the install's address under your person's name, " \
        "replies going to them, a copy to them unless copy_me is false. subject and body (HTML or plain text) are required: start from a template with show_lead_email (template_id). " \
        "step_id: the step it does, ticked off once sent. It goes in the lead's history.",
      params: { email: { to: "string[]", subject: "string!", body: "text!", step_id: "integer", template_id: "integer", copy_me: "boolean" } },
      confirm: "It goes to someone outside the business, from your address.", next_tools: %i[show_lead]
    agent_tool :show_lead_email, on: :new, title: "Draft an email to a lead",
      description: "Who it can go to and, with template_id (or step_id, using the template its step starts from), that template filled in for the lead: subject and body to edit before send_lead_email.",
      params: { template_id: "integer", step_id: "integer", to: "string" }

    before_action :set_lead

    def new
      @recipients = @lead.recipients
      raise Lead::Refused, "No email address for #{@lead.display_name}: add one first." if @recipients.empty?

      @step = @lead.steps.find_by(id: params[:step_id]) if params[:step_id].present?
      @template = Template.find_by(id: params[:template_id].presence || @step&.template_id)
      @to = Array(params[:to].presence || @recipients.first.email)
      to_person = @recipients.find { @to.include?(it.email) }
      @subject, @body = @template ? @template.fill(@lead, to: to_person, sender: Current.user.person) : [ "", "" ]
      @templates = Template.ordered.to_a
      @page_title = "Email #{@lead.display_name}"
    end

    def create
      attributes = params.expect(email: [ :subject, :body, :step_id, :template_id, :copy_me, to: [] ])
      allowed = @lead.recipients.map(&:email)
      to = Array(attributes[:to]).map { it.to_s.strip.downcase }.compact_blank.presence || allowed.first(1)
      raise Lead::Refused, "No email address for #{@lead.display_name}: add one first." if to.empty?
      raise Lead::Refused, "Only someone on the lead: #{allowed.to_sentence}." unless (to - allowed).empty?
      raise Lead::Refused, "Give it a subject." if attributes[:subject].blank?
      raise Lead::Refused, "Write something to send." if ActionController::Base.helpers.strip_tags(attributes[:body].to_s).squish.blank?

      sender = Current.user.person
      copy_me = attributes.key?(:copy_me) ? ActiveModel::Type::Boolean.new.cast(attributes[:copy_me]) : true
      body = attributes[:body].to_s.include?("<") ? attributes[:body].to_s : ActionController::Base.helpers.simple_format(attributes[:body].to_s)
      step = @lead.steps.find_by(id: attributes[:step_id]) if attributes[:step_id].present?

      OutboundMailer.with(to: to, subject: attributes[:subject].to_s.squish, body: body, sender: sender, copy_me: copy_me).to_lead.deliver_later
      @lead.log!("email", body: body, data: { sent: true, to: to, subject: attributes[:subject].to_s.squish, template_id: attributes[:template_id].presence&.to_i }.compact)
      @lead.complete_step!(step) if step && !step.done?

      redirect_to lead_path(@lead), notice: "Sent to #{to.to_sentence}#{"; #{step.title} is done" if step}."
    end
  end
end
