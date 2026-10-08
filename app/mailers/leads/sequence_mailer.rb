# A sequence's email (Leads::Step::Email), in the install's mail layout and from its sender. A
# lead's copy tracks its opens (a pixel) and clicks (links through Leads::Tracking::ClicksController)
# and carries the unsubscribe link, also as List-Unsubscribe with one-click POST (RFC 8058). A test
# copy has neither, so sending one changes no lead.
class Leads::SequenceMailer < ::ApplicationMailer
  def step_email
    @message = params[:message]
    @lead = @message.lead
    email = @message.step.email_for(@lead)
    @body_html = email.html(link: ->(url) { leads_mail_click_url(token: @message.click_token(url)) }).html_safe
    @text = email.text
    @open_url = leads_mail_open_url(token: @message.open_token)
    @unsubscribe_url = leads_mail_unsubscribe_url(token: @lead.unsubscribe_token)
    headers["List-Unsubscribe"] = "<#{@unsubscribe_url}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"

    mail to: @lead.email, subject: @message.subject, template_name: "email"
  end

  def test_email
    # The person stands in for a lead, so the placeholders read as theirs would.
    @lead = Leads::Lead.new(email: params[:to].email_address, name: params[:to].name)
    email = params[:step].email_for(@lead)
    @body_html = email.html.html_safe
    @text = email.text

    mail to: @lead.email, subject: "[Test] #{email.subject}", template_name: "email"
  end
end
