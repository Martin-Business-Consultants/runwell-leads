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
- The journey (3.1): a `Leads::Stage` has a plan (`Leads::PlaybookStep`: a title, `days_after`, an
  optional `Leads::Template`). `Lead#lay_out_plan!` (from the model's create and stage-change
  callbacks, so every surface does it) gives a lead the stage's steps (`Leads::Step`) it hasn't had.
  A lead's `next_step` / `next_step_on` columns are a copy of its earliest open step
  (`Lead#sync_next_step!`, after every step change): nothing writes them directly any more, and a
  next step given to `create_lead`, `update_lead` or `log_lead_activity` becomes a step
  (`Lead#add_step!`). Doing a step counts as being in touch (`last_activity_at`); `going_cold` is
  `Setting#cold_after_days` without one, read once per request (`PerRequest.cold_after_days`)
- `Leads::Person` is anyone else at the business; `Leads::Attachment` a file (Active Storage) or a
  link. `Leads::Win` makes each person a contact, each file a client `Document`, and an internal
  `Note` on the client with the story
- `Leads::EmailsController` sends to a lead (`OutboundMailer`, its own plain layout: from the
  install's address under the writer's name, reply-to and a copy to them), only to the lead's own
  addresses (`Lead#recipients`); `send_lead_email` declares `confirm:`. Sent mail is an `email`
  activity with `data.sent`. `Leads::DigestJob` is the morning email, planned nightly for
  `Setting#digest_hour`
- `Leads::Capture` turns a posted form into a lead: the standard fields, everything else as
  `details`, and the dedupe (external_id, then email: joins an open lead, reopens a lost one, a won
  one's person makes a new lead). `CapturesController` is the public endpoint (no sign-in, no CSRF,
  rate limited, found by a `CaptureKey` token, 404 while the plugin is off)
- `Leads::Win` is the only code that writes to the core: `Client.create!`, `client.contacts.create!`
  and `Work.create!`, through the core's models so their events and rules are the usual ones
- `Leads::Mailer` emails whoever `Leads::Setting#notified_people` names (every owner and manager
  until someone's picked) when a lead comes in or comes back, a person a lead is given to, and the
  morning digest
- A lead's `message` is rich text (the core's rule): a form's plain text reads fine through
  `rich_text`, and emails strip the tags
- Pages: `/leads` (table, or `?view=board` with the core's drag-and-drop posting to
  `DropsController`), `/leads/:id`, `/leads/:id/emails/new`, `/leads/:id/win/new`, `/leads/settings`
  (under Settings › Plugins). Every action has an agent tool, except the board's drops (`update_lead` moves a lead)
  and the capture keys (browser only)

## Rules

- Nothing reaches the core's clients before a lead is won. Don't add a client, contact or task for
  an open lead
- Tables are prefixed `leads_`, point at core records by id (`owner_id`, `client_id`), and migrations
  only add
- Release: bump `lib/leads/version.rb`, commit, tag `vX.Y.Z`, push the tag
