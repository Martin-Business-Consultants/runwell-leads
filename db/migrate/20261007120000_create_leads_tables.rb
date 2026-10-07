# frozen_string_literal: true

# The Leads plugin's tables. Leads point at core users (owner, assignee,
# author of an activity) by id, nullified when the user goes; everything a
# lead holds goes with it (deleting a lead is how someone is forgotten).
class CreateLeadsTables < ActiveRecord::Migration[8.1]
  def change
    create_table :leads_leads do |t|
      t.string :email, null: false
      t.string :name
      t.string :phone
      t.string :company
      t.string :source, null: false, default: "manual"
      t.integer :source_form_id
      t.string :stage, null: false, default: "new"
      t.integer :score, null: false, default: 0
      t.references :owner, foreign_key: {to_table: :users, on_delete: :nullify}
      t.json :fields, null: false, default: {}
      t.datetime :unsubscribed_at
      t.datetime :last_activity_at
      t.timestamps
    end
    add_index :leads_leads, :email, unique: true
    add_index :leads_leads, :stage
    add_index :leads_leads, :last_activity_at

    create_table :leads_sequences do |t|
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.string :trigger, null: false, default: "manual"
      t.integer :trigger_form_id
      t.string :trigger_stage
      t.timestamps
    end

    create_table :leads_steps do |t|
      t.references :sequence, null: false, foreign_key: {to_table: :leads_sequences, on_delete: :cascade}
      t.integer :position, null: false, default: 0
      t.integer :delay_amount, null: false, default: 1
      t.string :delay_unit, null: false, default: "days"
      t.string :subject, null: false
      t.text :body
      t.timestamps
    end

    create_table :leads_enrollments do |t|
      t.references :lead, null: false, foreign_key: {to_table: :leads_leads, on_delete: :cascade}
      t.references :sequence, null: false, foreign_key: {to_table: :leads_sequences, on_delete: :cascade}
      t.string :status, null: false, default: "active"
      t.integer :current_step, null: false, default: 0
      t.datetime :next_send_at
      t.datetime :last_sent_at
      t.datetime :finished_at
      t.string :stop_reason
      t.timestamps
    end
    add_index :leads_enrollments, [:status, :next_send_at]

    create_table :leads_messages do |t|
      t.references :lead, null: false, foreign_key: {to_table: :leads_leads, on_delete: :cascade}
      t.references :enrollment, foreign_key: {to_table: :leads_enrollments, on_delete: :nullify}
      t.references :step, foreign_key: {to_table: :leads_steps, on_delete: :nullify}
      t.string :subject, null: false
      t.datetime :sent_at
      t.datetime :opened_at
      t.datetime :clicked_at
      t.timestamps
    end

    create_table :leads_tasks do |t|
      t.references :lead, null: false, foreign_key: {to_table: :leads_leads, on_delete: :cascade}
      t.string :title, null: false
      t.date :due_on
      t.references :assignee, foreign_key: {to_table: :users, on_delete: :nullify}
      t.references :creator, foreign_key: {to_table: :users, on_delete: :nullify}
      t.datetime :done_at
      t.timestamps
    end
    add_index :leads_tasks, [:done_at, :due_on]

    create_table :leads_activities do |t|
      t.references :lead, null: false, foreign_key: {to_table: :leads_leads, on_delete: :cascade}
      t.string :kind, null: false
      t.string :summary, null: false
      t.text :body
      t.integer :points, null: false, default: 0
      t.json :data, null: false, default: {}
      t.references :user, foreign_key: {to_table: :users, on_delete: :nullify}
      t.datetime :created_at, null: false
    end
    add_index :leads_activities, [:lead_id, :created_at]
  end
end
