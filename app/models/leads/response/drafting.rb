# Asking the AI plugin for a lead's replies. It goes through the AI plugin's own chat (AiChat, as
# its suggestions do), so the install's provider, model and monthly budget apply, and what it cost
# shows in Settings › Plugins › AI. Strict JSON comes back; nothing is sent to the lead.
module Leads::Response::Drafting
  extend ActiveSupport::Concern

  SCHEMA = {
    type: "object", additionalProperties: false,
    required: %w[summary email text call next_step],
    properties: {
      summary: { type: "string", description: "One sentence: who they are and what they want, from what they sent" },
      email: { type: "object", additionalProperties: false, required: %w[subject body],
               properties: { subject: { type: "string" }, body: { type: "string", description: "Plain text, under 130 words, signed with the sender's first name" } } },
      text: { type: "string", description: "A text message under 300 characters that says who it's from" },
      call: { type: "object", additionalProperties: false, required: %w[opener questions objections close],
              properties: {
                opener: { type: "string", description: "The first two sentences to say" },
                questions: { type: "array", items: { type: "string" }, description: "3 to 5 discovery questions for this lead" },
                objections: { type: "array", items: { type: "object", additionalProperties: false, required: %w[objection answer],
                  properties: { objection: { type: "string" }, answer: { type: "string" } } }, description: "The 2 objections this lead is most likely to raise, with what to say" },
                close: { type: "string", description: "How to ask for the next step" }
              } },
      next_step: { type: "string", description: "The single best thing to do next with this lead, and when" }
    }
  }.freeze

  INSTRUCTIONS = <<~TEXT.freeze
    You are a sales coach helping someone on a small team reply to a lead: a person who got in touch and
    might become a client. They are often better at marketing than selling, so write replies they can
    send as they are, and a call plan that teaches as it guides.

    - Use only what the lead's details and timeline say. Never invent prices, dates, promises or facts about
      the business; where one is needed, leave "…" for the sender to fill in.
    - Be warm, plain and brief. No pressure, no hype, no exclamation marks in a row. Ask one clear question.
    - Every reply ends with a clear, easy next step (a call, a time, a yes or no).
    - Match the team's own templates for tone where they're given.
    - Write for whatever business this is; never assume an industry the details don't show.
    - The text message says who it's from and is fit to send during business hours.
  TEXT

  class_methods do
    # Whether drafting can run now: the AI plugin installed, switched on, set up and within budget.
    def available?
      defined?(::AiChat) && defined?(::Ai) && ::Ai.respond_to?(:available_for?) && ::Ai.available_for?
    rescue StandardError
      false
    end

    # Queued for a new lead (Settings › Leads can switch it off), or by someone on its Responses tab.
    def draft_later(lead, user: nil)
      user ||= lead.owner || User.active.people.where(role: "owner").order(:id).first
      return nil unless user && available?

      response = lead.responses.create!(user: user, state: "working")
      Leads::Response::DraftJob.perform_later(response)
      response
    end
  end

  # Called by DraftJob.
  def generate!
    chat = ::AiChat.start!(user: user, purpose: "suggestion")
    reply = chat.with_instructions(INSTRUCTIONS, persist: false).with_schema(SCHEMA.merge(name: "lead_replies")).ask(prompt)
    update!(state: "ready", ai_chat_id: chat.id, payload: reply.content.is_a?(Hash) ? reply.content : JSON.parse(reply.content.to_s), error: nil)
  rescue StandardError => e
    update!(state: "failed", error: "#{e.class.name.demodulize}: #{e.message}".truncate(300))
  end

  private
    def prompt
      sender = user&.person
      <<~TEXT
        The business: #{Setting.current.brand_name}. The sender: #{sender&.name.presence || sender&.display_name}.
        Today is #{Date.current.to_fs(:long)}.

        The lead:
        #{JSON.pretty_generate(lead_facts)}

        Recent timeline (newest first):
        #{lead.activities.limit(15).map { "- #{it.created_at.to_date}: #{it.summary}#{": #{Leads::Step::Email.plain_text(it.body).truncate(400)}" if it.note?}" }.join("\n").presence || "- nothing yet"}

        The team's own templates, for tone:
        #{Leads::Template.ordered.limit(6).map { "## #{it.kind_label}: #{it.title}\n#{Leads::Step::Email.plain_text(it.body).truncate(600)}" }.join("\n\n").presence || "none"}

        Draft the email, the text message and the call plan for this lead now, and say the best next step.
      TEXT
    end

    def lead_facts
      { name: lead.name, company: lead.company, has_email: lead.email.present?, has_phone: lead.phone.present?,
        stage: lead.stage, score: lead.score, came_from: lead.source_text, first_seen: lead.created_at.to_date,
        what_they_sent: lead.fields }
    end
end
