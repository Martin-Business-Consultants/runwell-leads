# The plugin's tables, prefixed with its key. A lead stays here from the first form to Won or Lost;
# only winning one touches the core (a client, a contact, maybe a piece of work).
class CreateLeadsTables < ActiveRecord::Migration[8.1]
  def change
    create_table :leads_stages do |t|
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :leads_leads do |t|
      t.string :name
      t.string :email
      t.string :phone
      t.string :company
      t.string :website
      t.text :message
      t.string :source
      t.string :external_id
      t.json :details, null: false, default: {}
      t.string :referrer_name
      t.string :referrer_email
      t.string :state, null: false, default: "open"
      t.integer :stage_id
      t.integer :owner_id
      t.integer :created_by_id
      t.integer :value_cents
      t.string :next_step
      t.date :next_step_on
      t.string :lost_reason
      t.integer :client_id
      t.datetime :closed_at
      t.integer :submissions_count, null: false, default: 1
      t.datetime :last_submitted_at
      t.datetime :last_activity_at
      t.timestamps
    end
    add_index :leads_leads, :external_id, unique: true
    add_index :leads_leads, :email
    add_index :leads_leads, %i[state stage_id]
    add_index :leads_leads, :owner_id
    add_index :leads_leads, :next_step_on
    add_index :leads_leads, :client_id

    create_table :leads_activities do |t|
      t.integer :lead_id, null: false
      t.integer :user_id
      t.string :kind, null: false
      t.text :body
      t.json :data, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :leads_activities, %i[lead_id created_at]

    create_table :leads_capture_keys do |t|
      t.string :name, null: false
      t.string :token, null: false
      t.integer :leads_count, null: false, default: 0
      t.datetime :last_used_at
      t.timestamps
    end
    add_index :leads_capture_keys, :token, unique: true

    create_table :leads_settings do |t|
      t.json :notify_user_ids, null: false, default: []
      t.timestamps
    end

    reversible do |dir|
      dir.up do
        now = Time.current.utc.iso8601
        [ "New", "Call booked", "Call held", "Proposal sent" ].each_with_index do |name, index|
          execute "INSERT INTO leads_stages (name, position, created_at, updated_at) VALUES (#{quote(name)}, #{index}, '#{now}', '#{now}')"
        end
      end
    end
  end
end
