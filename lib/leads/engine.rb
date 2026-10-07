# frozen_string_literal: true

module Leads
  # A CMS plugin (docs/plugins.md): it extends the core only through
  # Cms::Plugins and "<event>.cms" notifications, and the core never names it.
  class Engine < ::Rails::Engine
    initializer "leads.migrations" do |app|
      config.paths["db/migrate"].expanded.each { |path| app.config.paths["db/migrate"] << path }
    end

    # Routes join the app's own route set, so the core layout's helpers work
    # on the plugin's pages.
    initializer "leads.routes" do |app|
      app.routes.append do
        # Before `resources :leads`, so /leads/sequences isn't read as a lead.
        scope "leads", module: "leads", as: "leads" do
          resources :sequences, only: [:index, :new, :create, :edit, :update, :destroy] do
            resource :preview, only: :show, controller: "sequence_previews"
            resource :test, only: :create, controller: "sequence_tests"
          end
          resources :tasks, only: [:index, :edit, :update, :destroy] do
            resource :completion, only: [:create, :destroy], controller: "task_completions"
          end
          resources :bulk_stage_changes, only: :create
          resources :bulk_deletions, only: :create

          # What an email's links reach, public and signed (Leads::Mail::…).
          scope "mail/:token", module: "mail", as: "mail" do
            resource :open, only: :show
            resource :click, only: :show
            resource :unsubscribe, only: [:show, :create]
          end
        end

        resources :leads, module: "leads", only: [:index, :new, :create, :show, :update, :destroy], constraints: {id: /\d+/} do
          resources :notes, only: :create
          resources :tasks, only: :create
          resources :score_adjustments, only: :create
          resources :enrollments, only: [:create, :update]
          resource :subscription, only: :create
        end

        namespace :settings do
          resource :leads, only: [:show, :update], controller: "leads"
        end

        scope "api", module: "api/leads", as: "api", defaults: {format: :json} do
          resources :leads, only: [:index, :show, :create, :update, :destroy], constraints: {id: /\d+/} do
            resources :notes, only: :create
            resources :tasks, only: [:index, :create]
            resources :score_adjustments, only: :create
            resources :enrollments, only: :create
          end
          get "leads/sequences", to: "sequences#index", as: :leads_sequences
          get "leads/tasks", to: "tasks#index", as: :leads_tasks
        end
      end
    end

    # A form submission becomes (or updates) its lead, in a job so the
    # visitor's request never waits on it.
    initializer "leads.events" do
      ActiveSupport::Notifications.subscribe("submission.created.cms") do |event|
        next unless Cms::Plugins.enabled?(:leads)

        id = event.payload.dig(:data, :id)
        Leads::Lead.capture_later(id) if id
      end
    end

    config.to_prepare do
      Cms::Plugins.register :leads, name: "Leads", version: "1.0.0", author: "Martin Business Consultants",
        enabled_by_default: true, requires: ">= 1.0", depends_on: [:forms],
        homepage: "https://github.com/Martin-Business-Consultants/cms-leads",
        description: "Lead nurturing: every form submission with an email address becomes a lead with a timeline " \
                     "and a score, follow-up tasks, and email sequences that send, track opens and clicks, and " \
                     "let people unsubscribe.",
        adopt_if: -> { Leads::Lead.exists? }

      Cms::Plugins.menu :leads, :leads, label: "Leads", icon: "person", group: "Content", after: [:forms, :globals],
        path: -> { leads_path }, capability: "leads:read"
      Cms::Plugins.submenu :leads, :leads, label: "All leads", path: -> { leads_path }, capability: "leads:read"
      Cms::Plugins.submenu :leads, :leads, label: "Add new", path: -> { new_lead_path }, capability: "leads:write",
        after: "All leads"
      Cms::Plugins.submenu :leads, :leads, label: "Tasks", path: -> { leads_tasks_path }, capability: "tasks:read",
        after: "Add new"
      Cms::Plugins.submenu :leads, :leads, label: "Sequences", path: -> { leads_sequences_path },
        capability: "sequences:read", after: "Tasks"
      Cms::Plugins.new_item :leads, label: "Lead", path: -> { new_lead_path }, capability: "leads:write",
        after: ["Form", "Global"]
      Cms::Plugins.settings :leads, "Leads", -> { settings_leads_path },
        description: "Scoring, the qualification threshold, who sequence emails come from, and which forms make leads.",
        capability: "leads:read"
      Cms::Plugins.permissions :leads, "Leads",
        %w[leads:read leads:write leads:delete sequences:read sequences:write tasks:read tasks:write],
        after: ["Forms", "Globals"],
        defaults: {editor: %w[leads:read leads:write sequences:read sequences:write tasks:read tasks:write],
                   author: %w[leads:read tasks:read tasks:write],
                   agent: %w[leads:read sequences:read tasks:read]}
      Cms::Plugins.slot :dashboard, :leads, "leads/slots/dashboard"

      Cms::Plugins.counts :leads, after: :forms, leads: -> { Leads::Lead.count }, lead_sequences: -> { Leads::Sequence.count }
      # Sends the sequences' due steps (Leads::Enrollment::Deliverable).
      Cms::Plugins.minutely :leads, :sequences, -> { Leads::Enrollment.deliver_due_later }, every: 5
      Cms::Plugins.webhook_events :leads, "Leads",
        %w[lead.created lead.stage_changed lead.qualified lead.unsubscribed lead_task.created], after: "submission.created"

      Cms::Plugins.api :leads, "/api/leads", description: "Leads, newest activity first (?stage=, ?q=); create or update one by email."
      Cms::Plugins.api :leads, "/api/leads/:id", description: "A lead with its timeline, tasks and enrollments; update or delete it."
      Cms::Plugins.api :leads, "/api/leads/:lead_id/notes", description: "Add a note to a lead's timeline."
      Cms::Plugins.api :leads, "/api/leads/:lead_id/tasks", description: "A lead's follow-up tasks; add one."
      Cms::Plugins.api :leads, "/api/leads/:lead_id/score_adjustments", description: "Adjust a lead's score, with a reason."
      Cms::Plugins.api :leads, "/api/leads/:lead_id/enrollments", description: "Enroll a lead in a sequence."
      Cms::Plugins.api :leads, "/api/leads/sequences", description: "The email sequences, with their steps."
      Cms::Plugins.api :leads, "/api/leads/tasks", description: "Open tasks across every lead (?assignee=me, ?overdue=1)."
    end
  end
end
