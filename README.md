# Leads for Runwell

Leads from your website's forms and your calls, worked through to a sale, in
[Runwell](https://github.com/Martin-Business-Consultants/runwellv2). Nothing reaches your clients
until a lead is won: hundreds of enquiries a month stay out of the client list, and the ones you
win are copied over.

- **Leads come in from your forms.** Each form posts to its own address
  (`POST /leads/capture/<key>`, JSON or form fields). Name, email, phone, company, website and
  message become the lead; everything else (campaign, click ids, landing page, the form's own
  questions) is kept with it. A resent submission (same `external_id`) or the same email again
  joins the lead instead of making another; a lost lead whose person writes again reopens. A
  referral (`referral_company`, `referral_contact`, …) is the business referred, with the sender
  kept as who referred them.
- **Everyone works them.** A table with filters (open, needs attention, won, lost; owner; stage;
  source) and the bulk bar (give to someone, move, lose, delete), and a board of open leads by
  stage to drag between. Claim one that nobody has, or hand it to someone (they're emailed).
- **Every stage has a plan, and every lead follows it.** Arriving at a stage lays out that stage's
  steps on the lead, each due some days on: with the plan it starts with, a call held means the
  recap today and the proposal in two days, and a proposal sent means a check-in on day 2, a
  follow-up on day 5 and a last nudge on day 12. Tick steps off, move their dates, add your own.
  The earliest open step is the lead's next step. A lead gets a stage's steps once, however often
  it comes back. Plans are yours to change (Settings › Plugins › Leads).
- **Nothing slips.** An overdue next step, none past the first stage, or nobody in touch for a
  while (going cold, 10 days unless you change it) is flagged everywhere it shows, and each
  morning everyone with open leads is emailed what's due today or late and which are going cold;
  whoever's told about new leads also hears which nobody has.
- **Email them from the lead.** Start from a template (a recap, a proposal check-in, a last
  nudge, or your own, with `{{first_name}}`, `{{company}}`, `{{my_first_name}}` and more filled
  in), edit it, send. It goes from your Runwell's address under your name, replies come to you,
  and a copy lands in your inbox so the conversation carries on there. It's in the lead's history,
  and sending it for a step ticks the step off.
- **Everyone and everything in one place.** The other people at the business (who decides,
  who's keen, who else is involved), and files and links (the proposal, a deck, a Google Doc).
- **Calls, emails, meetings and notes** are logged on the lead, with its next step and stage in
  the same save, and its history shows every change and who made it.
- **Won** makes a client (or adds to one on file), its people as contacts, its files as the
  client's documents (kept from the portal), an internal note on the client telling the story so
  far (what they asked for, the calls and emails, its links), and optionally a first piece of work
  of the type you pick. **Lost** keeps it with a reason (not a fit, no budget, went
  quiet, chose someone else, not now, spam).
- **Settings** (Settings › Plugins › Leads): who's emailed when a lead comes in (every owner and
  manager until you pick), the morning email's hour and when a lead goes cold, the stages and
  their order, each stage's plan, the email templates, and the forms that send leads in.
- **Tools for AI**: list, show, add, change, claim, log a call (a debrief that moves the stage and
  plans the follow-ups agreed, in one call), add and tick off steps, add people and links, draft
  and send an email (it previews first), win, lose, reopen, bulk changes, plans, templates and the
  settings, so an agent can work leads through MCP or the `runwell` CLI like anything else.

## Install

In Runwell, Settings › Plugins: add `Martin-Business-Consultants/runwell-leads`, then switch it on.
Then in Settings › Plugins › Leads, add a form and paste its address into your website's form
handler. Check for bots on the website before posting (Cloudflare Turnstile, a honeypot): the
address adds whatever it's sent, up to 30 a minute from one address.

```bash
curl -X POST https://your-runwell/leads/capture/YOUR-FORM-KEY \
  -H "Content-Type: application/json" \
  -d '{"name":"Sam Lee","email":"sam@example.com","company":"Example Co","message":"We need a new website","source":"Homepage","utm_campaign":"spring","external_id":"form-123"}'
```

It answers `201 {"ok":true,"id":12,"outcome":"created"}` for a new lead, `200` when it joined one
(`again`, `returned`, `duplicate`), `422` when there's no name, email or company, `404` for a
form that's been deleted, and `429` past the limit.

## Upgrading to 3.1

3.1.1 fixes 3.1.0 on an install that once had Leads 2: two of 2's tables (`leads_templates`,
`leads_steps`) shared names with 3.1's, so 3.1.0's migration failed and Runwell wouldn't start. 3.1.1
renames 2's aside first (`leads_v2_*`), as 3.0 did with the rest.

Updating adds the plan, people, files and templates tables and a plan for each of the four stages
3.0 starts with (by name: a stage you renamed or added starts with none), with five templates, only
if you have none yet. Each open lead's next step becomes the first step of its plan. Leads already
at a stage don't get its plan: add their steps as you work them.

## Upgrading from Leads 2

3.0 replaces Leads 2 (scoring, email sequences and follow-ups, written for Runwell 2 and
the names Runwell 5 renamed). Updating sets 2's tables aside (`leads_v2_*`, kept, unread) and brings
its leads across: open ones (new, nurturing, qualified) at the first stage, customers won, lost
and spam lost; their owner, client, what their forms sent and their history; each one's earliest
open follow-up as its next step. The capture key comes across as a form, so the address your
website already posts to keeps working. Sequences, scores and templates don't come across: their
tables stay, unread.

Owners and managers mark leads won (`win_leads`); deleting needs Runwell's delete permission.
Requires Runwell 5.31 or later.

## License

FSL-1.1-MIT, like Runwell.
