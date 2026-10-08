module Leads
  # A Runwell plugin: it owns its tables (leads_*), points at core records by id, and reaches the
  # core only through the plugin contract (docs/plugin-contract.md in Runwell). Remove it and
  # Runwell runs as before.
  class Engine < ::Rails::Engine
    # Routes join the app's route set (as leads_*), so the core layout's helpers work on the
    # plugin's pages.
    initializer "leads.routes" do |app|
      app.routes.append do
        # Before `resources :leads`, so /leads/tasks isn't read as a lead.
        scope "leads", module: "leads", as: "leads" do
          resources :tasks, only: %i[index edit update destroy] do
            resource :completion, only: %i[create destroy]
          end
          resources :sequences do
            resources :steps, only: %i[create edit update destroy]
            resource :test, only: :create
          end
          resource :settings, only: %i[show update] do
            resource :capture_key, only: :create
          end

          # A website's form posts here (public, by the install's capture key).
          post "capture/:key", to: "captures#create", as: :capture
          match "capture/:key", to: "captures#preflight", via: :options, as: :capture_preflight

          # What an email's links reach, public and signed (Leads::Tracking::…).
          scope "mail/:token", module: "tracking", as: "mail" do
            resource :open, only: :show
            resource :click, only: :show
            resource :unsubscribe, only: %i[show create]
          end
        end

        resources :leads, module: "leads", only: %i[index new create show edit update destroy], constraints: { id: /\d+/ } do
          resources :notes, only: :create
          resources :tasks, only: :create
          resources :score_adjustments, only: :create
          resources :enrollments, only: %i[create update]
          resource :subscription, only: :create
          resource :conversion, only: :create
        end
      end
    end

    initializer "leads.helpers" do
      ActiveSupport.on_load(:action_view) { include Leads::LeadsHelper }
    end

    # The lead a client was won from, read on the client's page. Never a column on clients.
    initializer "leads.models" do
      ActiveSupport.on_load(:runwell_client) { has_one :won_lead, class_name: "Leads::Lead", dependent: :nullify }
    end

    config.to_prepare do
      Runwell::Plugins.register :leads, name: "Leads", version: Leads::VERSION, author: "Martin Business Consultants",
        enabled_by_default: false, requires: ">= 2.21.0", homepage: "https://github.com/Martin-Business-Consultants/runwell-leads",
        description: "The people who might become clients: captured from your website’s forms or added by hand, " \
                     "scored by what they do, followed up with tasks and email sequences, and made a client in one step."
      Runwell::Plugins.nav :leads, "Leads", -> { leads_path }
      Runwell::Plugins.settings :leads, "Leads", -> { leads_settings_path }
      Runwell::Plugins.permission :leads, :manage_sequences, name: "Write and switch on lead email sequences", roles: %w[owner manager]
      Runwell::Plugins.stylesheet :leads, "leads/leads"
      Runwell::Plugins.slot :client_aside, :leads, "leads/slots/client_aside"
      Runwell::Plugins.briefing :leads, "Lead follow-ups", partial: "leads/briefing/task",
        items: ->(user) { Leads::Task.pending.assigned_to(user).due_by(Date.current).in_due_order.includes(:lead) }
      # Each send is queued for its time as it's scheduled; this catches any that were missed
      # (a sequence switched back on, a send that failed, a restart).
      Runwell::Plugins.nightly :leads, -> { Leads::Enrollment.deliver_due_later }
      Runwell::Plugins.agent_workflow :leads, "Following up leads", <<~STEPS
        1. `list_leads` (stage: new or qualified) to see who needs attention, `show_lead` for one's timeline and tasks.
        2. `add_lead_note` for what was said, `add_lead_task` for the next step, `update_lead` to move its stage.
        3. `enroll_lead` to start an email sequence (it emails the lead, so it asks first).
        4. When they say yes, `convert_lead_to_client`: it makes the client and contact, and the lead becomes a customer.
      STEPS
    end
  end
end
