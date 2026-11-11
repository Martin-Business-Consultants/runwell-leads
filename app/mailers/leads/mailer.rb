module Leads
  # Tells the team about leads, in the core's email pieces: a new one (or one that came back) to
  # whoever Settings › Plugins › Leads names, and a lead given to someone, to them.
  class Mailer < ApplicationMailer
    # Everyone who hears about a new lead, each their own email, sent after it's saved.
    def self.notify_new(lead, returned: false)
      return unless Runwell::Plugins.enabled?(:leads)

      Setting.current.notified_people.each { with(lead: lead, user: it, returned: returned).arrived.deliver_later }
    end

    def arrived
      @lead, @user, @returned = params[:lead], params[:user], params[:returned]
      return unless @lead.open?

      @url = lead_url(@lead)
      subject = @returned ? "Back again: #{@lead.display_name}" : "New lead: #{@lead.display_name}"
      mail to: @user.email_address, subject: [ subject, (@lead.company if @lead.name.present? && @lead.company.present?) ].compact.join(", "),
        reply_to: (@lead.email if @lead.email)
    end

    def assigned
      @lead, @user, @by = params[:lead], params[:user], params[:by]
      return unless @lead.open? && @lead.owner == @user

      @url = lead_url(@lead)
      mail to: @user.email_address, subject: "Yours now: #{@lead.display_name}"
    end
  end
end
