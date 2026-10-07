# frozen_string_literal: true

require "rails_helper"
require Leads::Engine.root.join("spec/support/leads_helpers")

RSpec.describe Leads::Settings do
  it "starts from the defaults" do
    settings = Leads::Settings.current

    expect(%w[submission email_open email_click note].map { settings.points_for(it) }).to eq [10, 1, 3, 0]
    expect(settings.threshold).to eq 50
    expect(settings.capture?(make_form)).to be true
  end

  it "saves what Settings › Leads posts, keeping a number where it got none" do
    form = make_form
    sequence = make_sequence

    settings = Leads::Settings.update("points" => {"submission" => "15", "note" => "oops"}, "threshold" => "0",
      "from_name" => " Team ", "capture" => {"contact" => {"enabled" => "0", "sequence_id" => sequence.id.to_s}})

    expect(settings.points_for(:submission)).to eq 15
    expect(settings.points_for(:note)).to eq 0
    expect(settings.threshold).to eq 1
    expect(settings.capture?(form)).to be false
    expect(settings.sequence_for(form)).to eq sequence
    expect(settings.from_header).to start_with('"Team" <')
    expect(AuditLog.where(action: "settings.leads_updated")).to exist
  end

  it "signs emails with the core's sender, then the Forms plugin's" do
    Setting.set("forms_settings", {"from_name" => "Forms", "from_email" => "forms@example.com"})
    expect(Leads::Settings.current.from_header).to eq '"Forms" <forms@example.com>'

    Setting.set("general", {"email_from_name" => "Old Mill", "email_from_address" => "hi@example.com"})
    expect(Leads::Settings.current.from_header).to eq '"Old Mill" <hi@example.com>'
  end
end
