# Leads, a Runwell plugin — guide for AI agents

This repository is a plugin for Runwell (a Rails 8.1 engine loaded into a Runwell install). It is
not an app on its own: run it from a Runwell checkout with `bin/rails "plugins:link[path]"`.

Read first, in Runwell's repository:
- `docs/plugin-contract.md`: everything a plugin may rely on, with versions. Use nothing else of
  the core's. Raise `requires:` in the manifest to the newest version you use.
- `AGENTS.md`: the core's conventions, which plugin code follows too.

## Rules

- Own your tables, prefixed with the key (`leads_*`), pointing at core records by id. Never
  add columns to core tables or write core rows except through core model verbs.
- Register everything in `config.to_prepare`, keyed by the plugin's key. Controllers inherit
  `Leads::ApplicationController` (404 while switched off); subscribers check
  `Runwell::Plugins.enabled?(:leads)`.
- Every controller action declares an authorization rule (`allow_staff`, `require_permission`)
  and an `agent_tool` or `agent_exempt`. Reads get a `.json.jbuilder` view with `agent_ref` and a
  `summary`. Write notices an AI can act on.
- Views follow the core's ReActionView rules: strict locals on every partial's first line,
  `<%# herb:key %>` before each loop row, no inline CSS, no partials inside `form_with`. Use the
  core's helpers and shared partials (listed in the contract) and `term()` for the core's nouns.
- CSS uses Runwell's design tokens (`docs/theming.md`), in `@layer components`, with radii through
  `--radius-scale` / `--radius-control`.
- Migrations are safe on a live install: add in one release, remove only in a later one.
- Use only gems Runwell bundles: plugins load outside Bundler.
- Write for anyone running something (a business, a team, a household): never one industry's jargon.

## Layout

- `lib/leads/engine.rb`: routes, the client hook, registrations
- `app/`: models, controllers, views, stylesheets under `leads/`
- `db/migrate/`: the plugin's tables

## This plugin

- `Leads::Lead` and its concerns (`app/models/leads/lead/`) hold the verbs: `capture`,
  `record_activity`, `change_stage`, `revise`, `enroll`, `unsubscribe`, `convert_to_client!`.
  Controllers stay thin and call them.
- Public routes (`Leads::CapturesController`, `Leads::Tracking::*`) inherit `::ApplicationController`
  with `allow_unauthenticated_access`; unsubscribing works even while the plugin is off.
- Sends are scheduled per enrollment (`Deliverable#schedule_delivery`), claimed before sending so
  a send never goes twice, and swept nightly.
