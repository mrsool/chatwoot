<!-- Verbatim copy of the Phase 5 section of Confluence 'Chatwoot Integration' (page 3816423427), taken 2026-11-12. Confluence is authoritative. -->

## Phase 5 — Build Chatwoot Platform Capabilities 

**In plain English:** Premium Chatwoot still misses several Ops expectations we want from Intercom-class WFM and live ops: **mandatory Away reasons**, **idle → “still there?” → Away**, **auto-requeue when Away**, a **live SLA wallboard**, compensation **caps admin UI**, custom metrics reporting. Because we **self-host**, we implement these **in the Chatwoot codebase**.

**Estimate: not asserted.** Two readings of this phase are in circulation — three or four items and about a week, or the fourteen sub-tickets below across three waves. They cannot both be right, and the difference decides whether 1 January is real.

**So we price it by building one.** **P5.1** (Away reasons CRUD + mandatory Away on agent status) is the smallest item and the most representative: it touches Chatwoot's models, its agent-status logic, its Vue admin and its test setup, and it forces one rebase. **Two days, Mon 28 – Tue 29 Sep.** Phase 5 then gets an estimate the same way Phases 3 and 4 got theirs — measured, not asserted.

If the spike comes back long, the next question is immediately *which* of the fourteen Ops actually needs before January. Worth Ahmed forming that view in parallel rather than starting it cold.

**This is a fork and there is no way around it.** Away-with-reason and idle detection are agent-status behaviours inside Chatwoot's own interface; SLA-Live is a page in its dashboard. They cannot be built alongside in MBO. P5.11 — the upgrade/rebase runbook — is a real line item, not overhead.

**Goal:** Close [Feature List \<-\> Chatwoot Support](https://mrsool.atlassian.net/wiki/spaces/mfb/pages/3816652806/Feature+List+-+Chatwoot+Support)  **Not Supported** items that belong in the agent product + **SLA-Live**.  
 **Depends on:** Phases 1–4 usable enough for real agents; Premium **SLA policies** enabled before SLA-Live. Best **after** a Phase 6 pilot so we extend the inbox agents already use.  
 **Owners:** Backend on the Chatwoot repo; small MBO hooks where noted. Ops defines Away reason lists, idle minutes, SLA “at risk” thresholds, and which AI reports are wave 1.

**Recommended delivery waves (same phase, ordered):**

| Wave | Ship | Why first |
| --- | --- | --- |
| **5a** | Away reasons + idle confirm + requeue + **SLA-Live** | Day-to-day Ops / pilot trust |
| **5b** | Compensation caps admin (AD-13) | Ops edits caps without an MBO deploy |
| **5c** | AI quality (B-18, B-20, AD-18–20) | Needs bot traffic from Phase 4 to be meaningful |

---

### 5.1 Away with mandatory reason (A-08, AD-10)

**Agent experience today (gap):** Chatwoot only has online / busy / offline. There is **no** mandatory “why are you Away?” (break, prayer, training, …).

**What we build**

1. Availability **Away** that **requires** selecting an Away reason before save.
2. Admin UI to **create / edit / deactivate** Away reasons (AD-10) — account-scoped list Ops owns.
3. Agent UI: toggling Away opens reason picker; cannot go Away without a reason.
4. Persist reason on each availability change (for “time in reason” reporting).
5. Optional: supervisors see current Away reason on the live agent list.

**Technical contract**

| Piece | Detail |
| --- | --- |
| Table `away_reasons` | `id`, `account_id`, `label` (or AR/EN fields), `active`, `position`, timestamps |
| Table `agent_availability_events` (or extend existing availability) | `user_id`, `account_id`, `status` (`online`\|`busy`\|`away`\|`offline`), `away_reason_id` (required if away), `changed_at` |
| API | Admin CRUD `.../away_reasons`; agent `POST .../availability` with `status` + `away_reason_id` when Away |
| UI | Settings → Away reasons; agent status menu in dashboard |

**Not the same as:** “Mark offline automatically” (`auto_offline`) — that is WebSocket disconnect, **not** Away-with-reason.

---

### 5.2 Idle detection → confirm → Away (A-09, AD-08)

**Agent experience today (gap):** No mouse/keyboard idle timer, no “Are you still there?”, no auto-Away.

**What we build**

1. Admin setting: **idle timeout minutes** before prompt (AD-08).
2. Dashboard idle timer resets on activity (mouse / keyboard / focus — document the exact rule).
3. At timeout: modal “Still there?”; Confirm → stay Online/Busy; ignore/timeout → **Away**.
4. Away reason rule (pick one and stick to it): system reason `idle_auto` **or** force the reason picker.
5. Depends on §5.1 (Away reasons exist first).

**Technical contract**

| Piece | Detail |
| --- | --- |
| Account setting | `idle_away_timeout_minutes` (null = feature off) |
| Optional setting | `idle_away_reason_id` if auto-Away skips the picker |
| Frontend | Idle detector + modal; calls availability API from §5.1 |
| Specs | Timer fires; confirm cancels Away; ignore applies Away |

---

### 5.3 Requeue open chats when agent goes Away (B-06)

**Gap:** Agent goes Away/offline with open chats → customers sit on a silent assignee. Need return to queue within \~**5 seconds**.

**What we build**

1. On transition **to Away** (and optionally Offline): unassign that agent’s open/pending conversations back to the inbox/team queue.
2. Latency budget: visible in queue within \~5s.
3. Optional activity/private note: “Requeued — agent Away: {reason}”.
4. Optional webhook to MBO so local complaint assignee stays consistent.

**Technical contract**

| Piece | Detail |
| --- | --- |
| Trigger | After availability update to `away` / `offline` |
| Job | `Conversations::RequeueOnAwayJob` (batch per agent) |
| Scope | Open/pending assigned to that agent; skip resolved; honour inbox assignment settings |
| Webhook (optional) | `agent_away_requeued` → MBO with conversation ids |
| Metric | Away click → unassigned \< 5s p95 |

---

### 5.4 Compensation / lateness caps admin (AD-13)

**Gap:** Caps live in MBO config/code. Ops should edit thresholds **without a deploy**. Chatwoot still does **not** pay customers — MBO executes B-14.

**What we build**

1. Chatwoot admin UI for lateness thresholds, compensation amounts, max events per user/period.
2. MBO **reads** caps at compensate time.
3. Audit: who changed caps when.

**Technical contract**

| Piece | Detail |
| --- | --- |
| Store | `compensation_cap_settings` (account-scoped typed columns or JSONB): amounts, thresholds, max events, window days, `updated_by` |
| API | Admin CRUD; `GET .../compensation_caps` with account API token for MBO |
| MBO | Before compensate: fetch caps (short TTL cache); reject over-cap |
| UI | Settings → Compensation caps |

---

### 5.5 Live SLA board (**SLA-Live**)

**Premium already gives:** SLA **policies**, conversation badges/countdowns, breach **email**, **Reports → SLA Reports** (historical hit rate / breach table).

**Gap:** Team leads need a **live** wallboard of **open** chats at risk / breached that updates without a manual refresh (T14-style).

**What we build**

| Deliverable | Behaviour |
| --- | --- |
| Live page | e.g. Reports → **Live SLA** |
| Rows | Open conversations with Applied SLA; **on track** / **at risk** / **breached** for FRT, NRT, RT |
| At-risk rule | Account setting: e.g. \< 20% of threshold remaining |
| Metrics strip | Open breached count, at-risk count, rolling hit rate for recent SLA conversations (window agreed with Ops) |
| Filters | Inbox, team, assignee, label, SLA policy, `cr_code` / country (custom attributes from Phase 1) |
| Drill-down | Click → open conversation in inbox |
| Live refresh | ActionCable (or poll ≤5s) when SLA status changes |
| Breach webhook (optional) | `POST` to MBO on breach — Premium does not fire this natively |

**Reuse, do not reinvent timers:** enterprise `sla_policies`, `applied_slas`, `sla_events`. SLA-Live is **read + present + notify**.

**Technical contract**

| Piece | Detail |
| --- | --- |
| Endpoint | `GET /api/v1/accounts/:id/reports/live_sla` (+ filters); returns rows + summary |
| Cable | `LiveSlaChannel` on Applied SLA / SlaEvent / status flip |
| Frontend | Vue reports page |
| Setting | `sla_at_risk_threshold_percent` |
| Webhook | Optional `sla_breached` payload: conversation id, display\_id, policy, timer type, agent |
| MBO (optional) | Receiver → PagerDuty / internal alert |

**Out of SLA-Live**

| Item | Where |
| --- | --- |
| Policy CRUD + historical SLA Reports | Premium configure (Phase 0) |
| Assign “already-breached first” | MBO assigner if required |
| Customer widget countdown | Out of scope unless Product asks later |

---

### 5.6 Sentiment storage hardening (B-18) — after Phase 4

**Phase 4 already:** CX sentiment → Chatwoot labels.  
 **Phase 5 adds:** durable score fields + supervisor visibility for reporting (feeds AD-19).

| Piece | Detail |
| --- | --- |
| Storage | `sentiment_score`, `sentiment_label` on conversation (and/or last message) |
| Job (optional) | Persist/backfill score if not written inline in Phase 4 |
| UI | Score on conversation header / sidebar for supervisors |

Does **not** replace CX `detectIntent` — stores/displays what Phase 4 produces.

---

### 5.7 Max clarifications → force handoff (AD-18)

**Bot gap:** After N clarification turns, stop looping — force / offer human handoff.

| Piece | Detail |
| --- | --- |
| Setting | Per inbox / AgentBot: `max_clarification_attempts` (stored in Chatwoot) |
| Counter | Conversation custom attr `clarification_count` (MBO AgentBot increments) |
| Action | On exceed: handoff message + `toggle_status` open (Phase 4 handoff helper) |

Prefer **MBO reads Chatwoot setting** so handoff rules stay next to bot orchestration.

---

### 5.8 AI vs workflow log diff (B-20)

**QA gap:** Compare AI/bot outcome vs expected workflow / CX path.

| Piece | Detail |
| --- | --- |
| Job | `Ai::WorkflowDiffJob` |
| Table `ai_workflow_diffs` | `conversation_id`, `expected`, `actual`, `status` (`match`\|`mismatch`), `reviewed_at` |
| UI | Supervisor queue of mismatches |

Depends on Phase 4 logging workflow cursor / CX metadata onto the conversation or MBO.

---

### 5.9 AI ops reports + hallucination review (AD-19, AD-20)

**Ops gap:** Deflection, escalation, AI handle time, hallucination flags; P1 for bad AI.

| Piece | Detail |
| --- | --- |
| Labels | Applied in Phase 4 (`ai-handled`, `ai-escalated`, `ai-hallucination`, …); Phase 5 **reports** on them |
| Reports page | Date/inbox/CR filters; deflection, escalation, AI handle time, hallucination count |
| Review queue | Conversations flagged hallucination; mark reviewed |
| P1 | New flag → PagerDuty/OpsGenie (Chatwoot webhook or MBO) |
| API | `GET .../reports/ai_ops` aggregations |

---

### 5.10 Arabic / RTL and branding patches (conditional)

**Only if** Phase 0 / Phase 2 verification fails. **Pilot-blocking** if broken.

| Area | Build if broken |
| --- | --- |
| Widget RTL | Bubbles, mixed AR/EN, timestamps, attachments |
| Agent dashboard RTL | Inbox list, composer, reports |
| Arabic search / sort | Real conversation data |
| Branding leftovers | Premium branding first; patch stragglers |

No new tables — layout/CSS PRs + rebase notes.

---

### 5.11 Explicitly not Phase 5

| Item | Phase |
| --- | --- |
| CX canvas / main sentiment **product** path (label + escalate) | **4** |
| CR catalog, create/resume, push, sidebar | **1–3** |
| Historical Premium SLA Reports / policy CRUD | Native (Phase 0) |

---

### Technical contract (Phase 5) — repo & upgrade rules

| Rule | Detail |
| --- | --- |
| Where code lives | Self-hosted Chatwoot; prefer `enterprise/` overlays / `prepend_mod_with` where patterns allow |
| Migrations | New tables account-scoped (`away_reasons`, caps, diffs, …) |
| Specs | Model + request + feature specs per wave (Away, idle, requeue, live\_sla minimum for 5a) |
| Feature flags | Independently disable 5a / 5b / 5c if an upstream upgrade breaks one slice |
| Upstream | Written rebase/runbook; CI on fork |

**MBO hooks summary**

| Hook | Purpose |
| --- | --- |
| `GET` compensation caps | Enforce before B-14 |
| Optional `sla_breached` webhook | Alerting |
| Optional Away requeue webhook | Sync local assignee |
| Assign API | “Breached SLA first” stays MBO if required |
| AgentBot | Read `max_clarification_attempts`; bump `clarification_count` |

---

### Done when (Phase 5)

**Wave 5a**

- Agent cannot go Away without a reason; admin can CRUD reasons
- Idle timeout prompts and moves to Away when configured
- Away/offline requeues open chats within \~5s
- Live SLA page shows at-risk/breached open chats with live refresh + drill-down

**Wave 5b**

- Ops edits compensation caps in Chatwoot; MBO enforces on compensate

**Wave 5c**

- Sentiment score stored/visible; clarification cap forces handoff; AI diff + AI ops report + hallucination review/alert as scoped

**Conditional:** RTL patches merged if verification failed.

---

