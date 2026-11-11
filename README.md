# Leads for Runwell

Leads from your website's forms, worked through to a sale, in
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
- **Every open lead has a next step.** What happens next, and by when. One with an overdue next
  step, or none past the first stage, is flagged everywhere it shows.
- **Calls, emails, meetings and notes** are logged on the lead, with its next step and stage in
  the same save, and its history shows every change and who made it.
- **Won** makes a client (or adds to one on file), its person as a contact, and optionally a first
  piece of work of the type you pick. **Lost** keeps it with a reason (not a fit, no budget, went
  quiet, chose someone else, not now, spam).
- **Settings** (Settings › Plugins › Leads): who's emailed when a lead comes in (every owner and
  manager until you pick), the stages and their order, and the forms that send leads in.
- **Tools for AI**: list, show, add, change, claim, log a call (a debrief with its next step),
  win, lose, reopen, bulk changes and the settings, so an agent can work leads through MCP or the
  `runwell` CLI like anything else.

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
