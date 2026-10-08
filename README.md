# Leads for Runwell

The people who might become clients, before they are: captured from your website’s forms or
added by hand, scored by what they do, followed up with tasks and email sequences, and made a
client in one step.

A Runwell plugin (Runwell’s `docs/plugins.md`): a Rails engine that owns its `leads_*` tables,
reaches core records (users, clients) by id, and extends the core only through the plugin
contract. Needs Runwell 2.21 or newer.

## Install

Settings › Plugins › Install, with `Martin-Business-Consultants/runwell-leads`, or from the shell:

    bin/rails "plugins:install[Martin-Business-Consultants/runwell-leads]"

Then switch it on in Settings › Plugins. Remove deletes its code and keeps its tables.

## What it does

- **Leads**: one per email address, with name, phone, company, owner, stage (`new`,
  `nurturing`, `qualified`, `customer`, `lost`), score, where it came from, and what its forms
  sent. Leads in the nav, with All leads, Follow-ups and Email sequences beside it.
- **From your website**: a form posts to `/leads/capture/<key>` (Settings › Leads shows the
  address, an HTML form and a `fetch` example). `email` is all it needs; `name` (or `first_name`
  and `last_name`), `phone` and `company` fill in the lead, `source` names the form, and
  everything else is kept on the lead. A browser goes on to `redirect_to`, else the thanks page
  in Settings, else a short thank-you; a script gets JSON (201, or 422 without an email), from any
  origin. A hidden `website_url` field catches bots, and posts are rate limited per address.
- **Timeline**: coming in, emails sent, opened and clicked, stage and score changes, notes,
  follow-ups, sequences started and left, unsubscribing, becoming a client.
- **Scoring**: points per thing a lead does (defaults: coming in 10, an email opened 1, a link
  clicked 3, a note 0; the first open and first click of each email count) and adjustments by
  hand with a reason. Reaching the threshold (default 50) qualifies a new or nurturing lead.
- **Follow-ups**: tasks on a lead (what, by when, who). Yours that are due show on home as
  “Lead follow-ups”.
- **Email sequences**: emails sent one after another, each a delay in hours or days after the
  lead joined or the email before, in rich text with `{{name}}`, `{{first_name}}`, `{{email}}`
  and `{{company}}`. A sequence starts by hand, when a lead comes in from the website (any form,
  or one `source`), or when a lead reaches a stage, and sends only while it’s on. Each send is
  queued for its moment, and the nightly run catches any that were missed. “Send me a test”
  sends every email to you. Starting one makes a new lead nurturing; unsubscribing, becoming a
  customer or being lost stops them.
- **Emails**: in the install’s mail layout, from its sender (Settings › Email). Every one has a
  signed one-click unsubscribe link (also as `List-Unsubscribe` / `List-Unsubscribe-Post`,
  RFC 8058), an open pixel and click-tracked links, at `/leads/mail/:token/…`.
- **Becoming a client**: “Make a client” creates the client (named for the company, else the
  lead) with the lead as its contact, or uses the ones that already exist. The lead becomes a
  customer, and the client’s sidebar shows the lead it came from.
- **Privacy**: deleting a lead deletes its timeline, follow-ups, sequences and sent-email records.

## Permissions

Everyone on staff works leads, follow-ups and enrollments. Deleting a lead takes Runwell’s
“delete records” (owners and managers). Writing and switching on sequences takes “Write and
switch on lead email sequences” (owners and managers). Settings › Leads takes “manage settings”.

## Agents

Every page has its tool: `list_leads`, `show_lead`, `create_lead`, `update_lead`, `delete_lead`,
`add_lead_note`, `add_lead_task`, `list_lead_tasks`, `complete_lead_task`, `adjust_lead_score`,
`enroll_lead` and `resubscribe_lead` (both ask first, since they email someone),
`convert_lead_to_client`, the sequence tools, and the settings. “Following up leads” is offered
to agents as a workflow.

## Developing

Clone it beside a Runwell checkout, then from Runwell:

    bin/rails "plugins:link[../runwell-leads]"
    bin/rails db:migrate
    bin/dev

`bin/rails agent:coverage`, `bundle exec herb lint ../runwell-leads/app/views` and
`bin/rubocop ../runwell-leads` should all be clean.

## Releasing

Bump `lib/leads/version.rb`, commit, and push a matching `vX.Y.Z` tag: the release workflow
publishes it, and installs see it as an update in Settings › Plugins.
