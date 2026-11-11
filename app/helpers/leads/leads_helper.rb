module Leads
  # What the leads' pages share: how a lead's stage, attention and value read, the people and
  # stages to pick from, and the form's details in words.
  module LeadsHelper
    # Field names websites send, said the way people read them; anything else is humanized.
    DETAIL_LABELS = {
      "utm_source" => "Campaign source", "utm_medium" => "Campaign medium", "utm_campaign" => "Campaign", "utm_term" => "Search term",
      "utm_content" => "Ad", "gclid" => "Google click", "fbclid" => "Facebook click", "msclkid" => "Microsoft click",
      "landing_path" => "Landed on", "form_path" => "Form on", "referrer" => "Came from", "ip_country" => "Country",
      "submitted_at" => "Sent", "user_agent" => "Browser"
    }.freeze
    # Shown last and quietly: for tracing, not for selling.
    QUIET_DETAILS = %w[external_id user_agent v submitted_at gclid fbclid msclkid].freeze

    def lead_stage_badge(lead)
      if lead.won? then badge("won", "Won", tone: :ok)
      elsif lead.lost? then badge("lost", lead.state_label, tone: :outline)
      else badge(lead.stage&.name || "No stage", tone: :outline)
      end
    end

    def lead_attention_badge(lead)
      badge(lead.attention_label, tone: :attention) if lead.attention
    end

    # "Call them back · Nov 14", the date marked when it's gone.
    def lead_next_step(lead)
      return tag.span("—", class: "faint") if lead.next_step.blank? && lead.next_step_on.nil?

      date = tag.span(lead.next_step_on.strftime("%b %-d"), class: class_names("leads-date", "leads-date--late": lead.attention == :overdue)) if lead.next_step_on
      safe_join([ (tag.span(lead.next_step, class: "leads-next__step") if lead.next_step), date ].compact, " · ")
    end

    def lead_value(lead) = lead.value_cents ? money(lead.value_cents) : nil

    def leads_people = (@leads_people ||= User.people.active.ordered.to_a)
    def lead_owner_options = [ [ "Nobody", "nobody" ] ] + leads_people.map { [ it.display_name, it.id ] }
    def lead_stage_options = Stage.options

    def lead_detail_label(key) = DETAIL_LABELS[key] || key.to_s.humanize

    # The form's details, the telling ones first.
    def lead_details(lead)
      lead.details.to_h.compact_blank.sort_by { |key, _| [ QUIET_DETAILS.include?(key) ? 1 : 0, DETAIL_LABELS.keys.index(key) || 0 ] }
    end

    def lead_activity_icon(activity)
      { "call" => "bolt", "email" => "email", "meeting" => "calendar", "note" => "comment", "created" => "add", "submitted" => "paper-plane",
        "owner" => "person", "stage" => "arrow-right", "next_step" => "marker", "won" => "check-circle", "lost" => "close-circle",
        "reopened" => "refresh", "value" => "tag" }[activity.kind] || "dot"
    end

    def lead_mail_link(lead)
      return unless lead.email

      mail_to lead.email, lead.email
    end

    def lead_website_link(lead)
      return unless lead.website

      url = lead.website.match?(%r{\Ahttps?://}i) ? lead.website : "https://#{lead.website}"
      link_to lead.website.sub(%r{\Ahttps?://}i, "").delete_suffix("/"), url, target: "_blank", rel: "noopener"
    end
  end
end
