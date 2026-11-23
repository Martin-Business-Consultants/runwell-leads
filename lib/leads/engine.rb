module Leads
  # Leads from a website, worked through to a sale (README.md). It owns its tables (leads_*),
  # points at core records by id, and reaches the core only through the plugin contract
  # (docs/plugin-contract.md in Runwell): winning a lead makes a client, a contact and maybe a piece
  # of work through the core's models. Remove it and Runwell runs as before.
  class Engine < ::Rails::Engine
    # Routes join the app's route set, so the core layout's helpers work. The fixed paths come
    # before the leads themselves, so /leads/settings isn't read as a lead.
    initializer "leads.routes" do |app|
      app.routes.append do
        scope "leads", module: "leads", as: "leads" do
          post "capture/:token", to: "captures#create", as: :capture, constraints: { token: /[A-Za-z0-9_-]{16,64}/ }
          resource :settings, only: %i[show update]
          resources :stages, only: %i[create update destroy]
          resources :playbook_steps, path: "plans", only: %i[create update destroy]
          resources :templates, only: %i[create update destroy]
          resource :digest, only: :create
          resources :capture_keys, path: "forms", only: %i[create destroy]
          resource :bulk, only: %i[update destroy], controller: "bulk"
          post "stages/:stage_id/drops/:id", to: "drops#create", as: :stage_drop
        end
        resources :leads, module: "leads" do
          resource :claim, only: :create
          resource :win, only: %i[new create]
          resource :loss, only: :create
          resource :reopening, only: :create
          resources :activities, only: %i[create destroy]
          resources :steps, only: %i[create update destroy]
          resources :people, only: %i[create update destroy]
          resources :attachments, path: "files", only: %i[create destroy]
          resources :emails, only: %i[new create]
        end
      end
    end

    initializer "leads.models" do
      ActiveSupport.on_load(:runwell_client) { has_many :leads_leads, class_name: "Leads::Lead", dependent: :nullify }
      ActiveSupport.on_load(:runwell_user) { has_many :leads_leads, class_name: "Leads::Lead", foreign_key: :owner_id, inverse_of: :owner, dependent: :nullify }
    end

    initializer "leads.helpers" do
      ActiveSupport.on_load(:action_view) { include Leads::LeadsHelper }
    end

    config.to_prepare do
      Runwell::Plugins.register :leads, name: "Leads", version: Leads::VERSION, author: "Martin Business Consultants",
        enabled_by_default: false, requires: ">= 5.31.0", homepage: "https://github.com/Martin-Business-Consultants/runwell-leads",
        description: "Leads from your website's forms and your calls, worked through to a sale: a board and a table by stage, and a plan for each stage " \
          "(a recap the day of the call, the proposal two days on, follow-ups after) laid out on every lead as it arrives, with email templates to start from. " \
          "Email a lead from its page, keep the people, files and links on it, and get each morning's follow-ups and leads going cold by email. " \
          "Winning one makes it a client with its contacts, files and story; nothing reaches your clients before that. Tools for AI to work them too."
      Runwell::Plugins.nav :leads, "Leads", -> { leads_path }, icon: "person-add"
      Runwell::Plugins.permission :leads, :win_leads, name: "Mark leads won, making them clients", roles: %w[owner manager]
      Runwell::Plugins.stylesheet :leads, "leads/leads"
      Runwell::Plugins.settings :leads, "Leads", -> { leads_settings_path if can?(:manage_settings) }
      Runwell::Plugins.nightly :leads, -> { Leads::DigestJob.schedule }
    end
  end
end
