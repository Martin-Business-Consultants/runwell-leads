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
        description: "Leads from your website's forms, worked through to a sale: each one's stage, owner and next step, a board and a table, " \
          "calls and notes, and the people told when one comes in. Winning one makes it a client (with its contact and first work); " \
          "nothing reaches your clients before that. Tools for AI to work them too."
      Runwell::Plugins.nav :leads, "Leads", -> { leads_path }, icon: "person-add"
      Runwell::Plugins.permission :leads, :win_leads, name: "Mark leads won, making them clients", roles: %w[owner manager]
      Runwell::Plugins.stylesheet :leads, "leads/leads"
      Runwell::Plugins.settings :leads, "Leads", -> { leads_settings_path if can?(:manage_settings) }
    end
  end
end
