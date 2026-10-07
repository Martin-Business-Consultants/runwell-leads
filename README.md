# Leads

Lead nurturing for the CMS (LibrePublish): every form submission with an email
address becomes a lead, with a timeline, a score, follow-up tasks and email
sequences that send themselves, track opens and clicks, and let people
unsubscribe in one click.

A plugin in the sense of the core's `docs/plugins.md`: a Rails engine that owns
its `leads_*` tables, reaches core records (users, forms) by id, and extends
the core only through `Cms::Plugins`. It depends on the
[Forms](https://github.com/Martin-Business-Consultants/cms-forms) plugin and is
on by default.

## Install

    bin/rails "plugins:install[https://github.com/Martin-Business-Consultants/cms-leads]"

That clones it into `plugins/leads`, bundles, migrates and restarts Puma.
`bin/rails "plugins:remove[cms-leads]"` takes it out again; its tables stay.

## What it does

- **Leads** — one per email address (normalized), with name, phone, company,
  source (the form it first came from, added by hand, or the API), stage
  (`new`, `nurturing`, `qualified`, `customer`, `lost`), score, owner (a CMS
  user), whether it unsubscribed, when it was last active, and the fields it
  last submitted.
- **Capture** — the plugin listens for the Forms plugin's `submission.created`
  and, in a job, creates or updates the lead for the submission's email (the
  form's first email field, or a field named `email`; name, phone and company
  from the usual field names), recording "Submitted <form>". Settings › Leads
  can switch a form off and name the sequence its new leads join.
- **Timeline** — submissions, emails sent/opened/clicked, stage and score
  changes, notes, tasks added and done, enrollments started, stopped and
  finished, unsubscribes.
- **Scoring** — points per event (defaults: submission 10, email opened 1,
  link clicked 3, note 0; the first open and first click of each email count)
  and manual adjustments with a reason. Crossing the threshold (default 50)
  moves a new or nurturing lead to qualified, with a `lead.qualified` webhook.
- **Tasks** — follow-ups on a lead (title, due date, assignee). The Tasks
  screen shows yours, everyone's or the done ones, overdue first; the
  dashboard's "Tasks due" panel shows the signed-in person's.
- **Sequences** — ordered emails (subject and Markdown body, with
  `{{name}}`, `{{first_name}}`, `{{email}}`, `{{company}}`), each sent a delay
  in hours or days after the enrollment (the first) or the email before. A
  sequence starts by hand, when a form is submitted, or when a lead reaches a
  stage, and sends only while it's switched on. Every 5 minutes the plugin's
  minutely task queues `Leads::Enrollment::DeliveryJob`, which sends the due
  steps. Enrolling a new lead makes it "nurturing"; unsubscribing, becoming a
  customer or being lost stops its sequences. The editor has a preview and
  "Send test" (every step, to you).
- **Emails** — simple inline-styled HTML plus text, from the sender in
  Settings › Leads (else Settings › General's, then Forms', then the
  install's). Every email has a signed one-click unsubscribe link (also as
  `List-Unsubscribe` / `List-Unsubscribe-Post`, RFC 8058), an open pixel and
  click-tracked links. These public routes live under `/leads/mail/:token/…`
  on the CMS's host.
- **Privacy** — deleting a lead deletes its activities, tasks, enrollments
  and sent-email records.

## Screens

Content › Leads: All leads (a tab per stage, owner filter, search, bulk
"set to stage" and delete), a lead's page (details, stage and owner, timeline
and notes, score and adjustment, tasks, sequences), Add new, Tasks,
Sequences (list, editor, preview). Settings › Leads: points, threshold,
sender, and per form whether it makes leads and which sequence new ones join.

## Permissions

| Capability | Editor | Author | Agent |
|---|---|---|---|
| `leads:read` | ✓ | ✓ | ✓ |
| `leads:write` (details, stage, notes, scores, enrollments) | ✓ | | |
| `leads:delete` | | | |
| `sequences:read` | ✓ | | ✓ |
| `sequences:write` | ✓ | | |
| `tasks:read` | ✓ | ✓ | ✓ |
| `tasks:write` | ✓ | ✓ | |

Admins hold everything. Settings › Leads needs `leads:read` to open and
`leads:write` to save.

## API

All JSON, with a bearer token (`Authorization: Bearer …`) whose role holds
the capability.

| Endpoint | |
|---|---|
| `GET /api/leads` | `?stage=`, `?q=`, `?page=`, `?per=` |
| `POST /api/leads` | `{lead: {email, name, phone, company, stage, owner_id}}` — creates the lead (201) or updates the one with that email (200) |
| `GET /api/leads/:id` | with `fields`, `activities`, `tasks`, `enrollments` |
| `PATCH /api/leads/:id` | as POST |
| `DELETE /api/leads/:id` | with everything it holds |
| `POST /api/leads/:lead_id/notes` | `{note: {body}}` |
| `GET, POST /api/leads/:lead_id/tasks` | `{task: {title, due_on, assignee_id}}` |
| `POST /api/leads/:lead_id/score_adjustments` | `{score_adjustment: {points, reason}}` |
| `POST /api/leads/:lead_id/enrollments` | `{enrollment: {sequence_id}}`; 422 with the reason when it can't |
| `GET /api/leads/sequences` | sequences and their steps |
| `GET /api/leads/tasks` | open tasks across leads, overdue first; `?assignee=me`, `?overdue=1`, `?done=1` |

They're listed with the plugin in `/api/manifest`, whose `counts` gain
`leads` and `lead_sequences`.

## Events

Webhooks can subscribe to (and in-process code hears as `"<event>.cms"`):

- `lead.created` — a new lead, from a form, by hand or over the API
- `lead.stage_changed` — the lead, with `previous_stage`
- `lead.qualified` — its score crossed the threshold
- `lead.unsubscribed`
- `lead_task.created`

The audit log records `lead.*`, `lead_task.*`, `lead_sequence.*`,
`lead_enrollment.stopped` and `settings.leads_updated`.

## Development

From the core checkout, with this repository in `plugins/leads`:

    bin/rspec plugins/leads/spec
    bundle exec herb lint plugins/leads
    bin/rubocop plugins/leads
