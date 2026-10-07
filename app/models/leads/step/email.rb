# frozen_string_literal: true

# A step's email as one lead gets it: the placeholders filled in, the body's
# Markdown drawn as HTML (sanitized as the admin's Markdown previews are),
# and every http(s) link passed through `link` — the mailer's click tracking.
class Leads::Step::Email
  def initialize(step, lead)
    @step = step
    @lead = lead
  end

  def subject = personalize(@step.subject).squish

  def text = personalize(@step.body.to_s)

  # link: ->(url) { url to put in its place }, for tracked links.
  def html(link: ->(url) { url })
    rendered = Markdown.to_html(text)
    clean = Rails::HTML5::SafeListSanitizer.new.sanitize(rendered, tags: Markdown::TAGS, attributes: Markdown::ATTRIBUTES)
    fragment = Nokogiri::HTML5.fragment(clean)
    fragment.css("a[href]").each do |anchor|
      anchor["href"] = link.call(anchor["href"]) if anchor["href"].match?(%r{\Ahttps?://}i)
    end
    fragment.to_html
  end

  private

  def personalize(source)
    source.to_s.gsub(/\{\{\s*(\w+)\s*\}\}/) do
      key = Regexp.last_match(1)
      Leads::Step::PLACEHOLDERS.include?(key) ? value_for(key) : Regexp.last_match(0)
    end
  end

  def value_for(key)
    case key
    when "name" then @lead.name.presence || "there"
    when "first_name" then @lead.name.to_s.split.first.presence || "there"
    when "email" then @lead.email.to_s
    when "company" then @lead.company.to_s
    end
  end
end
