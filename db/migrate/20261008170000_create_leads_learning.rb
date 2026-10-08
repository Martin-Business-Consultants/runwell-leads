# The Learning Center's templates (email, text and call), the AI's drafted replies for a lead, and
# the switches for both in Settings › Leads.
class CreateLeadsLearning < ActiveRecord::Migration[8.1]
  def change
    create_table :leads_templates do |t|
      t.string :kind, null: false, index: true
      t.string :title, null: false
      t.string :situation
      t.string :subject
      t.text :body
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :leads_responses do |t|
      t.references :lead, null: false, foreign_key: { to_table: :leads_leads, on_delete: :cascade }
      t.integer :user_id
      t.integer :ai_chat_id
      t.string :state, null: false, default: "working"
      t.json :payload, null: false, default: {}
      t.text :error
      t.timestamps
    end

    add_column :leads_settings, :templates_seeded_at, :datetime
    add_column :leads_settings, :ai_drafts, :boolean, null: false, default: true
  end
end
