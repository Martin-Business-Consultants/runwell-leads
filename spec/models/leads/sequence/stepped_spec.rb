# frozen_string_literal: true

require "rails_helper"
require Leads::Engine.root.join("spec/support/leads_helpers")

RSpec.describe Leads::Sequence::Stepped do
  let(:sequence) { make_sequence(steps: 3) }

  it "saves the rows in the order posted: kept, added and removed" do
    first, second, third = sequence.steps.to_a
    rows = [{"id" => third.id.to_s, "subject" => "Third first", "delay_amount" => "1", "delay_unit" => "hours", "body" => "x"},
      {"subject" => "Brand new", "delay_amount" => "3", "delay_unit" => "days", "body" => "y"},
      {"id" => first.id.to_s, "subject" => first.subject, "delay_amount" => "0", "delay_unit" => "days", "body" => "z"}]

    expect(sequence.save_with_steps({name: "Renamed"}, rows)).to be true

    expect(sequence.reload.name).to eq "Renamed"
    expect(sequence.steps.map(&:subject)).to eq ["Third first", "Brand new", first.subject]
    expect(sequence.steps.map(&:position)).to eq [0, 1, 2]
    expect(Leads::Step.exists?(second.id)).to be false
  end

  it "keeps everything as it was when a row is invalid" do
    rows = [{"subject" => "", "delay_amount" => "1", "delay_unit" => "days"}]

    expect(sequence.save_with_steps({name: "Renamed"}, rows)).to be false
    expect(sequence.reload.steps.size).to eq 3
  end

  it "reads the editor's rows in posted order" do
    expect(Leads::Sequence.step_rows({"b" => {"subject" => "B"}, "a" => {"subject" => "A"}}).map { it["subject"] }).to eq %w[B A]
  end

  it "needs the form or stage its trigger names" do
    expect(Leads::Sequence.new(name: "X", trigger: "form")).not_to be_valid
    expect(Leads::Sequence.new(name: "X", trigger: "stage", trigger_stage: "won")).not_to be_valid
    expect(Leads::Sequence.new(name: "X", trigger: "stage", trigger_stage: "qualified")).to be_valid
  end
end
