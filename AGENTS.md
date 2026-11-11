# Leads (a Runwell plugin): guide for AI agents

A Rails engine loaded into a Runwell install (README.md says what it does). Run it from a Runwell
checkout with `bin/rails "plugins:link[path]"`. Read Runwell's `docs/plugin-contract.md` (use
nothing of the core's beyond it) and its `AGENTS.md` (the conventions this code follows).

## How it's built

- `Leads::Lead` (`leads_leads`) is one lead from first form to won or lost, and the only place its
  rules live. State: open, then won (`win!`, through `Leads::Win`) or lost (`lose!`, with a reason
  from `LOST_REASONS`); a lost lead reopens (`reopen!`), a won one never does. Open leads sit in a
  `Leads::Stage` (`leads_stages`, ordered; the first is where new ones land). Each verb refuses a
  move the state doesn't allow (`Lead::Refused`, in words a person or an agent can act on; the
  controllers' `rescue_from` turns it into an alert). `attention` (overdue, no next step) and
  `needing_attention` are the one definition of a lead that needs someone
- Every change of owner, stage, next step or value records a `Leads::Activity` from the model's
  `after_update`, by `::Current.user`, so the table, board, bulk bar and agents all leave the same
  history. People log calls, emails, meetings and notes (`Activity::LOGGED`). The per-request cache
  is `Leads::PerRequest`, never `Leads::Current`, so `Current.user` inside `module Leads` stays the
  core's
- `Leads::Capture` turns a posted form into a lead: the standard fields, everything else as
  `details`, and the dedupe (external_id, then email: joins an open lead, reopens a lost one, a won
  one's person makes a new lead). `CapturesController` is the public endpoint (no sign-in, no CSRF,
  rate limited, found by a `CaptureKey` token, 404 while the plugin is off)
- `Leads::Win` is the only code that writes to the core: `Client.create!`, `client.contacts.create!`
  and `Work.create!`, through the core's models so their events and rules are the usual ones
- `Leads::Mailer` emails whoever `Leads::Setting#notified_people` names (every owner and manager
  until someone's picked) when a lead comes in or comes back, and a person a lead is given to
- A lead's `message` is rich text (the core's rule): a form's plain text reads fine through
  `rich_text`, and emails strip the tags
- Pages: `/leads` (table, or `?view=board` with the core's drag-and-drop posting to
  `DropsController`), `/leads/:id`, `/leads/:id/win/new`, `/leads/settings` (under Settings ›
  Plugins). Every action has an agent tool, except the board's drops (`update_lead` moves a lead)
  and the capture keys (browser only)

## Rules

- Nothing reaches the core's clients before a lead is won. Don't add a client, contact or task for
  an open lead
- Tables are prefixed `leads_`, point at core records by id (`owner_id`, `client_id`), and migrations
  only add
- Release: bump `lib/leads/version.rb`, commit, tag `vX.Y.Z`, push the tag
