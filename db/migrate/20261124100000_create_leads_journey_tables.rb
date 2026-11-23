# 3.1's journey: what happens after the first call. A stage's plan (its steps, each due some days
# after a lead arrives there, and the email template it starts from), the steps laid out on each
# lead, the other people at a lead's business, its files and links, the email templates, and the
# morning reminder's settings. Only adds.
class CreateLeadsJourneyTables < ActiveRecord::Migration[8.1]
  def change
    create_table :leads_templates do |t|
      t.string :name, null: false
      t.string :subject, null: false
      t.text :body
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :leads_playbook_steps do |t|
      t.integer :stage_id, null: false
      t.string :title, null: false
      t.integer :days_after, null: false, default: 0
      t.integer :template_id
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :leads_playbook_steps, %i[stage_id position]

    create_table :leads_steps do |t|
      t.integer :lead_id, null: false
      t.string :title, null: false
      t.date :due_on
      t.datetime :done_at
      t.integer :done_by_id
      t.integer :playbook_step_id
      t.integer :template_id
      t.integer :created_by_id
      t.timestamps
    end
    add_index :leads_steps, %i[lead_id done_at]
    add_index :leads_steps, :due_on
    add_index :leads_steps, %i[lead_id playbook_step_id]

    create_table :leads_people do |t|
      t.integer :lead_id, null: false
      t.string :name, null: false
      t.string :email
      t.string :phone
      t.string :title
      t.string :role
      t.timestamps
    end
    add_index :leads_people, :lead_id

    create_table :leads_attachments do |t|
      t.integer :lead_id, null: false
      t.string :name
      t.string :url
      t.integer :user_id
      t.timestamps
    end
    add_index :leads_attachments, :lead_id

    add_column :leads_settings, :digest_hour, :integer, default: 7
    add_column :leads_settings, :cold_after_days, :integer, default: 10
  end
end
