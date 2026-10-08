# The Leads plugin's tables, prefixed with its key. Users and clients are the core's, pointed at
# by id; everything a lead holds goes with it (deleting a lead is how someone is forgotten).
class CreateLeads < ActiveRecord::Migration[8.1]
  def change
    create_table :leads_leads do |t|
      t.string :email, null: false, index: { unique: true }
      t.string :name
      t.string :phone
      t.string :company
      t.string :source, null: false, default: "manual"
      t.string :source_label
      t.string :stage, null: false, default: "new", index: true
      t.integer :score, null: false, default: 0
      t.integer :owner_id, index: true
      t.integer :client_id, index: true
      t.json :fields, null: false, default: {}
      t.datetime :unsubscribed_at
      t.datetime :last_activity_at, index: true
      t.timestamps
    end

    create_table :leads_sequences do |t|
      t.string :name, null: false
      t.boolean :active, null: false, default: false
      t.string :trigger, null: false, default: "manual"
      t.string :trigger_source
      t.string :trigger_stage
      t.timestamps
    end

    create_table :leads_steps do |t|
      t.references :sequence, null: false, foreign_key: { to_table: :leads_sequences, on_delete: :cascade }
      t.integer :position, null: false, default: 0
      t.integer :delay_amount, null: false, default: 1
      t.string :delay_unit, null: false, default: "days"
      t.string :subject, null: false
      t.text :body
      t.timestamps
    end

    create_table :leads_enrollments do |t|
      t.references :lead, null: false, foreign_key: { to_table: :leads_leads, on_delete: :cascade }
      t.references :sequence, null: false, foreign_key: { to_table: :leads_sequences, on_delete: :cascade }
      t.string :status, null: false, default: "active"
      t.integer :current_step, null: false, default: 0
      t.datetime :next_send_at
      t.datetime :last_sent_at
      t.datetime :finished_at
      t.string :stop_reason
      t.timestamps
      t.index %i[status next_send_at]
    end

    create_table :leads_messages do |t|
      t.references :lead, null: false, foreign_key: { to_table: :leads_leads, on_delete: :cascade }
      t.references :enrollment, foreign_key: { to_table: :leads_enrollments, on_delete: :nullify }
      t.references :step, foreign_key: { to_table: :leads_steps, on_delete: :nullify }
      t.string :subject, null: false
      t.datetime :sent_at
      t.datetime :opened_at
      t.datetime :clicked_at
      t.timestamps
    end

    create_table :leads_tasks do |t|
      t.references :lead, null: false, foreign_key: { to_table: :leads_leads, on_delete: :cascade }
      t.string :title, null: false
      t.date :due_on
      t.integer :assignee_id, index: true
      t.integer :creator_id
      t.datetime :done_at
      t.timestamps
      t.index %i[done_at due_on]
    end

    create_table :leads_activities do |t|
      t.references :lead, null: false, foreign_key: { to_table: :leads_leads, on_delete: :cascade }
      t.string :kind, null: false
      t.string :summary, null: false
      t.text :body
      t.integer :points, null: false, default: 0
      t.json :data, null: false, default: {}
      t.integer :user_id
      t.datetime :created_at, null: false
      t.index %i[lead_id created_at]
    end

    # Settings › Leads, one row: the points each thing is worth, the score that qualifies a lead,
    # and the key a website's form posts with.
    create_table :leads_settings do |t|
      t.json :points, null: false, default: {}
      t.integer :threshold, null: false, default: 50
      t.string :capture_key, null: false
      t.string :thanks_url
      t.timestamps
    end
  end
end
