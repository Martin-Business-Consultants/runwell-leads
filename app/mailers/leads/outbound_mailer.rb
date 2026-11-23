module Leads
  # An email to a lead, written on its page (Leads::EmailsController): from the install's address
  # under the writer's name, replies going to the writer, and a copy to them so the conversation
  # carries on from their own inbox. Plain, like a person's email: no logo, button or footer.
  class OutboundMailer < ApplicationMailer
    layout "leads/outbound"

    # The body as plain text: paragraphs and list items on their own lines.
    def self.plain_text(html)
      text = html.to_s.gsub(%r{<br\s*/?>}i, "\n").gsub(%r{</(p|div|h\d|blockquote|ul|ol)>}i, "\n\n").gsub(/<li[^>]*>/i, "- ").gsub(%r{</li>}i, "\n")
      CGI.unescapeHTML(ActionController::Base.helpers.strip_tags(text)).gsub(/\n{3,}/, "\n\n").strip
    end

    def to_lead
      @body, sender = params[:body], params[:sender]
      from = ::Mail::Address.new(::Mail::Address.new(::Setting.current.mail_sender).address)
      from.display_name = "#{sender.display_name} at #{::Setting.current.brand_name}"

      mail to: params[:to], subject: params[:subject], from: from.to_s, reply_to: sender.email_address,
        bcc: (sender.email_address if params[:copy_me])
    end
  end
end
