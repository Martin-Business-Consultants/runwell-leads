# A step's email as one lead gets it: the placeholders filled in (escaped), the rich text body
# sanitized, every http(s) link passed through `link` (the mailer's click tracking), and a plain
# text part drawn from the same HTML.
class Leads::Step::Email
  TAGS = %w[p br strong b em i u s a ul ol li blockquote h1 h2 h3 h4 pre code hr].freeze

  # Rich text as plain text, links as "text (url)".
  def self.plain_text(html)
    fragment = Nokogiri::HTML5.fragment(html.to_s)
    fragment.css("a[href]").each { |a| a.replace("#{a.text} (#{a["href"]})") unless a.text == a["href"] }
    fragment.css("br").each { it.replace("\n") }
    fragment.css("p, li, h1, h2, h3, h4, blockquote, pre").each { it.add_next_sibling("\n\n") }
    fragment.text.gsub(/[ \t]+\n/, "\n").gsub(/\n{3,}/, "\n\n").strip
  end

  def initialize(step, lead)
    @step = step
    @lead = lead
  end

  def subject = personalize(@step.subject) { it }.squish

  # link: ->(url) { url to put in its place }, for tracked links.
  def html(link: ->(url) { url })
    personalized = personalize(@step.body.to_s) { ERB::Util.html_escape(it) }
    clean = Rails::HTML5::SafeListSanitizer.new.sanitize(personalized, tags: TAGS, attributes: %w[href])
    fragment = Nokogiri::HTML5.fragment(clean)
    fragment.css("a[href]").each { |anchor| anchor["href"] = link.call(anchor["href"]) if anchor["href"].match?(%r{\Ahttps?://}i) }
    fragment.to_html
  end

  def text = self.class.plain_text(html)

  private
    def personalize(source)
      source.to_s.gsub(/\{\{\s*(\w+)\s*\}\}/) do
        key = Regexp.last_match(1)
        Leads::Step::PLACEHOLDERS.include?(key) ? yield(value_for(key)) : Regexp.last_match(0)
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
