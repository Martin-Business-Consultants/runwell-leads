# frozen_string_literal: true

# Shared by the plugin's specs (required from each, as the core's
# rails_helper loads only its own spec/support).
module LeadsSpecHelpers
  def make_form(slug = "contact", fields: nil, **attrs)
    fields ||= [{"name" => "name", "label" => "Name", "type" => "text"},
      {"name" => "email", "label" => "Email", "type" => "email", "required" => true},
      {"name" => "phone", "label" => "Phone", "type" => "tel"},
      {"name" => "message", "label" => "Message", "type" => "textarea"}]
    Form.create!({slug: slug, title: slug.titleize, status: "published", fields: fields}.merge(attrs))
  end

  def make_lead(email = "sam@example.com", **attrs)
    Leads::Lead.create!({email: email, name: "Sam Lee"}.merge(attrs))
  end

  def make_sequence(name = "Welcome", steps: 2, **attrs)
    sequence = Leads::Sequence.create!({name: name, active: true}.merge(attrs))
    steps.times do |index|
      sequence.steps.create!(position: index, delay_amount: index.zero? ? 0 : 2, delay_unit: "days",
        subject: "Step #{index + 1} for {{first_name}}", body: "Hello {{name}}, see [our menu](https://example.com/menu).")
    end
    sequence.reload
  end
end

RSpec.configure do |config|
  config.include LeadsSpecHelpers
end
