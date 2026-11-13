# Fazaa Phase 5 — Wave 5a (WFM + SLA-Live) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship wave 5a inside the Chatwoot fork: Away with a mandatory reason (A-08, AD-10), idle → "Still there?" → Away (A-09, AD-08), requeue an agent's open chats on Away/Offline within ~5s (B-06), and a live SLA wallboard (SLA-Live, §5.5).

**Architecture:** All Mrsool backend code lives in a new `custom/` extension folder, loaded through Chatwoot's existing `prepend_mod_with` / `include_mod_with` mechanism (`ChatwootApp.extensions` already returns `%w[enterprise custom]` when `custom/` exists). `enterprise/` is never edited. Upstream files are touched only where no hook exists; each such touch is listed in `custom/FORK_NOTES.md` for rebases. SLA-Live reads the enterprise SLA tables (`applied_slas`, `sla_policies`, `sla_events`) and adds no timers of its own.

**Tech Stack:** Rails 7.2, PostgreSQL, Sidekiq, RSpec; Vue 3 + Vuex, Vitest (`pnpm test`).

**Spec:** `docs/superpowers/specs/2026-11-12-fazaa-phase5-platform-capabilities.md` (verbatim copy of the Confluence "Chatwoot Integration" Phase 5 section; Confluence page 3816423427 is authoritative). This plan covers §5.1, §5.2, §5.3, §5.5 only.

## Global Constraints

- Never modify anything under `enterprise/`. New backend code goes under `custom/`; mirror enterprise's layout (`custom/app/models/custom/...` for overlays, `custom/app/{models,controllers,jobs,policies,views}` for new classes).
- Every upstream file touched must get one line in `custom/FORK_NOTES.md`: path, what changed, why there was no hook.
- Two account feature flags, both non-premium, appended at the end of `config/features.yml` with `column: feature_flags_ext_1`, mirrored in `app/javascript/dashboard/featureFlags.js`:
  - `fazaa_wfm` gates §5.1–5.3 (Away reasons, idle, requeue).
  - `fazaa_sla_live` gates §5.5 and also requires the existing `sla` flag.
- Spec latency budget: from the Away click to the conversation being unassigned in under 5s at p95. Requeue jobs go on the `high` queue.
- Spec at-risk rule: a timer is **at risk** when the time remaining is less than `sla_at_risk_threshold_percent`% of that timer's threshold. The default is `20`.
- Spec live refresh: the page must update without a manual refresh, either through ActionCable or a poll every ≤5s.
- Every new user-facing string goes in both `en` and `ar` locale files (dashboard `i18n/locale/{en,ar}/*.json`, backend `config/locales/{en,ar}.yml`).
- Commit style: conventional commits scoped to the area, e.g. `feat(wfm): …`, `feat(sla-live): …`, `test(wfm): …`.

## Decisions made in this plan (my calls, not the spec's)

- **Away is a fourth availability value**, `away: 3`, on the `AccountUser.availability` enum. It is not Busy with a reason. `InboxAgentAvailability#available_agents` already selects only `'online'`, so Away agents automatically get no new auto-assignments.
- **One label per reason** (`name`), not separate Arabic and English fields. Ops writes the label in whichever language their agents use.
- **Idle auto-Away uses a configured reason** (`idle_away_reason_id`) instead of forcing the picker, because nobody is at the keyboard to pick one. The idle feature counts as on only when both `idle_away_timeout_minutes` and `idle_away_reason_id` are set.
- **"Still there?" stays open for 60 seconds** before Away is applied.
- **Requeue triggers on explicit status changes only**: the picker, idle auto-Away, or an admin changing it. A dropped WebSocket (`auto_offline` presence expiry) does not change the `availability` column, so it doesn't trigger a requeue. That case is out of scope for 5a.
- **SLA-Live refreshes by polling every 5s**, plus a client-side clock for countdowns. The at-risk state changes with time passing, not with an event, so ActionCable alone would not keep the page current.
- **The rolling hit rate** is `hit / (hit + missed + active_with_misses)` over `applied_slas` whose `updated_at` falls within the last `sla_live_hit_rate_window_hours`, default `24`. Ops can tune the window.
- **Out of scope for 5a:** all of the optional spec items. That is the `agent_away_requeued` and `sla_breached` webhooks to MBO, and supervisors seeing an agent's Away reason in the live agent list.

## Review Focus

1. **Several dashboard tabs open:** typing in one tab must keep the idle timer from firing in the others. Pinned in Task 6 (activity is shared across tabs through `localStorage`).
2. **A reason deactivated while an agent is Away with it:** the agent stays Away and the reason still shows. Only *new* Away transitions require an active reason. Pinned in Task 2.
3. **An admin sets an agent to Away from Agents settings without a reason:** the request returns 422 with a readable error, not a 500. Pinned in Task 2.
4. **An agent with 0 open chats goes Away:** no job errors and no activity notes are created. **A chat resolved while the requeue job is queued:** it is skipped. Both pinned in Task 3.
5. **An account with `sla` off but `fazaa_sla_live` on:** the endpoint returns 403 rather than an empty board. Pinned in Task 7.

---

### Task 1: `custom/` extension wiring, feature flags, Away reasons API

**Files:**
- Create: `custom/FORK_NOTES.md`
- Modify: `config/application.rb:42-53` (add `custom/` load paths, views and initializers, mirroring the enterprise lines). Note it in FORK_NOTES.
- Modify: `config/features.yml` (append `fazaa_wfm` and `fazaa_sla_live`), `app/javascript/dashboard/featureFlags.js`
- Create: `db/migrate/20261112100000_create_away_reasons.rb`
- Create: `custom/app/models/away_reason.rb`, `custom/app/policies/away_reason_policy.rb`, `custom/app/controllers/api/v1/accounts/away_reasons_controller.rb`, `custom/app/views/api/v1/accounts/away_reasons/{index,show,create,update}.json.jbuilder`, `custom/app/views/api/v1/models/_away_reason.json.jbuilder`
- Modify: `config/routes.rb` (`resources :away_reasons, only: [:index, :create, :update, :destroy]` inside the accounts scope, next to `sla_policies` at ~L162). Note it in FORK_NOTES.
- Test: `spec/custom/models/away_reason_spec.rb`, `spec/custom/controllers/api/v1/accounts/away_reasons_controller_spec.rb`

**Interfaces:**
- Produces:
  - `AwayReason(id, account_id, name:string not null, active:boolean default true, position:integer default 0, timestamps)`, with a unique index on `[account_id, lower(name)]`
  - `AwayReason.active` scope; default order `position, id`
  - `Account has_many :away_reasons, dependent: :destroy_async` via `custom/app/models/custom/concerns/account.rb` (`include_mod_with('Concerns::Account')` already exists)
  - REST at `/api/v1/accounts/:account_id/away_reasons`:
    - `index` is open to any agent and returns active reasons. Admins can pass `?all=true` to include inactive ones.
    - `create` and `update` are admin-only; params are `name`, `active`, `position`.
    - `destroy` is admin-only and is a soft deactivate (`active: false`).
    - JSON shape: `{id, name, active, position}`.
  - Every action returns 403 unless `Current.account.feature_enabled?('fazaa_wfm')`.

- [ ] **Step 1: Write the failing specs**
  - **Model:** `name` is required. A duplicate name in the same account is invalid, ignoring case. The same name in another account is valid. `active` scope.
  - **Controller (follow `spec/enterprise/controllers/api/v1/accounts/sla_policies_controller_spec.rb`):**
    - With the flag off, 403.
    - An agent `GET index` sees only active reasons, in `position` order.
    - An agent `POST` gets 401/403.
    - An admin `POST {name: "Prayer"}` gets 200 and the row exists.
    - An admin `DELETE` sets `active: false` and does not remove the row.
    - An admin `GET ?all=true` includes inactive reasons.
- [ ] **Step 2: Run them and confirm they fail**
  - Run: `bundle exec rspec spec/custom`
  - Expected: FAIL with `uninitialized constant AwayReason`
- [ ] **Step 3: Implement the wiring, flags, migration, model, policy, controller, views and route**
  - Copy the structure of the enterprise SLA policies controller and policy. The feature check is `raise Pundit::NotAuthorizedError unless Current.account.feature_enabled?('fazaa_wfm')`.
  - `custom/FORK_NOTES.md` lists each upstream file touch, one line each.
- [ ] **Step 4: Run the specs and confirm they pass**
  - Run: `bundle exec rspec spec/custom spec/enterprise/controllers/api/v1/accounts/sla_policies_controller_spec.rb`
  - Expected: PASS. The enterprise spec proves the wiring didn't break existing overlays.
- [ ] **Step 5: Commit** with `feat(wfm): away reasons API behind fazaa_wfm, custom/ extension wiring`

### Task 2: Away availability with a mandatory reason, plus the event log

**Files:**
- Modify: `app/models/account_user.rb:35` → `enum availability: { online: 0, offline: 1, busy: 2, away: 3 }`. Note it in FORK_NOTES, since enums can't be overlaid.
- Create: `db/migrate/20261112100100_add_away_reason_to_account_users.rb`. It adds `account_users.away_reason_id` (nullable FK to `away_reasons`, `on_delete: :nullify`) and creates table `agent_availability_events(account_id, user_id, status:integer, away_reason_id nullable, changed_at:datetime not null)` with an index on `[account_id, user_id, changed_at]`.
- Create: `custom/app/models/custom/concerns/account_user.rb` (loaded by the existing `include_mod_with('Concerns::AccountUser')`), `custom/app/models/agent_availability_event.rb`
- Modify: `app/controllers/api/v1/profiles_controller.rb:57` (permit `:away_reason_id`) and the agents controller's permitted params (`app/controllers/api/v1/accounts/agents_controller.rb`). Note both in FORK_NOTES.
- Modify: `app/views/api/v1/profiles/availability.jbuilder` and the account_user fields in the profile/agent jbuilders, so `away_reason_id` and `away_reason_name` are returned. Note it in FORK_NOTES.
- Modify: `config/locales/{en,ar}.yml`, adding the validation message `away_reason_required`
- Test: `spec/custom/models/account_user_away_spec.rb`, plus an added context in `spec/controllers/api/v1/profiles_controller_spec.rb` (around L285)

**Interfaces:**
- Consumes: `AwayReason` (Task 1)
- Produces:
  - `AccountUser#away?` (from the enum)
  - `AccountUser#away_reason` (`belongs_to :away_reason, optional: true`)
  - **Validation:** on a change *into* `away`, `away_reason_id` must be an active reason in the same account. Leaving `away` clears `away_reason_id`. An agent already Away keeps their reason even if it's deactivated later.
  - **Validation applies only** when the account has `fazaa_wfm` on. With the flag off, `away` is rejected as invalid.
  - **after_commit, on a saved change to `availability`:**
    - creates an `AgentAvailabilityEvent(status, away_reason_id, changed_at: Time.current)`
    - calls `Fazaa::AvailabilityChanged.call(account_user:, previous:)`. Task 3 implements it; in this task it's a no-op service, `custom/app/services/fazaa/availability_changed.rb`, whose `call` does nothing.
  - **API:** `POST /api/v1/profile/availability` with params `{account_id, availability: 'away', away_reason_id}`. A missing or inactive reason returns 422 with `{message}`. The same rules apply to the admin agents update endpoint.

- [ ] **Step 1: Write the failing specs**
  - Model:
    - Going away without a reason is invalid.
    - Going away with a reason from another account is invalid.
    - Going away with an inactive reason is invalid.
    - Going away with a valid reason saves, and writes 1 `AgentAvailabilityEvent` with that reason.
    - Away → online clears the reason and writes an event.
    - Deactivating the reason afterwards leaves the agent Away and the record valid on an unrelated save.
    - `inbox.available_agents` excludes an Away agent.
  - Request: profile availability `away` without a reason returns 422. With a reason, 200 and `away_reason_id` in the response. Admin agents update to `away` without a reason returns 422, not 500.
- [ ] **Step 2: Run them and confirm they fail**
  - Run: `bundle exec rspec spec/custom/models/account_user_away_spec.rb spec/controllers/api/v1/profiles_controller_spec.rb`
  - Expected: FAIL (`'away' is not a valid availability`)
- [ ] **Step 3: Implement the enum value, migration, concern, event model, no-op service, params and views**
- [ ] **Step 4: Run them, plus the existing availability and presence specs, and confirm they pass**
  - Run: `bundle exec rspec spec/custom spec/controllers/api/v1/profiles_controller_spec.rb spec/models/account_user_spec.rb spec/lib/online_status_tracker_spec.rb`
  - Expected: PASS
- [ ] **Step 5: Commit** with `feat(wfm): away availability with mandatory reason and availability event log`

### Task 3: Requeue open chats when an agent goes Away or Offline

**Files:**
- Modify: `custom/app/services/fazaa/availability_changed.rb`. When the new status is `away` or `offline`, the previous status was `online` or `busy`, and the account has `fazaa_wfm`, call `Fazaa::RequeueOnAwayJob.set(queue: :high).perform_later(account_user.account_id, account_user.user_id)`.
- Create: `custom/app/jobs/fazaa/requeue_on_away_job.rb`, `custom/app/models/custom/concerns/conversation.rb` (loaded by the existing `include_mod_with('Concerns::Conversation')`)
- Modify: `config/locales/{en,ar}.yml`, adding the key `conversations.activity.assignee.requeued_on_away`. English copy: `"Requeued — %{agent_name} is %{status}%{reason}"`, where `reason` is `": <name>"` or empty.
- Test: `spec/custom/jobs/fazaa/requeue_on_away_job_spec.rb`, `spec/custom/services/fazaa/availability_changed_spec.rb`

**Interfaces:**
- Consumes: `AccountUser` away/offline transitions (Task 2)
- Produces:
  - `Fazaa::RequeueOnAwayJob#perform(account_id, user_id)`. It does nothing if that user's current availability is back to `online`/`busy`, which handles a quick toggle.
  - Scope: `Conversation.where(account_id:, assignee_id: user_id, status: [:open, :pending])`.
  - For each conversation, under `Current.executed_by = nil` with a system actor, it unassigns through `Conversations::AssignmentService.new(conversation:, assignee_id: nil).perform`, so callbacks and webhooks fire. Then it posts the `requeued_on_away` activity note, then calls `conversation.fazaa_reassign_after_requeue!`.
  - `Conversation#fazaa_reassign_after_requeue!` is defined in the custom concern. When the inbox uses assignment v2 (`inbox.auto_assignment_v2_enabled?`) it calls `AutoAssignment::AssignmentJob.enqueue_for_inbox(inbox.id)`; otherwise `AutoAssignment::AgentAssignmentService.new(conversation: self, allowed_agent_ids: legacy_allowed_agent_ids).assign_under_lock`. This matches `AutoAssignmentHandler#run_auto_assignment` (`app/models/concerns/auto_assignment_handler.rb:24`). It does nothing when `inbox.enable_auto_assignment?` is false; the conversation then stays unassigned in the queue.
  - No `update_all`. The upstream activity note and webhooks must fire.

- [ ] **Step 1: Write the failing specs**
  - Service: online → away enqueues the job on `high`. busy → offline enqueues it. away → offline does not enqueue it again. The flag off enqueues nothing.
  - Job:
    - An agent with 2 open, 1 pending and 1 resolved chat → the 3 open/pending chats get `assignee_id: nil` and each gets one activity message containing the reason name. The resolved chat is untouched.
    - Legacy inbox with another online member → the chat is reassigned to that member, never to the Away agent.
    - Agent back online before the job runs → nothing changes.
    - Agent with 0 chats → no errors, no messages.
- [ ] **Step 2: Run them and confirm they fail**
  - Run: `bundle exec rspec spec/custom/jobs spec/custom/services`
  - Expected: FAIL
- [ ] **Step 3: Implement the service branch, job, concern method and i18n**
- [ ] **Step 4: Run them, plus the assignment specs, and confirm they pass**
  - Run: `bundle exec rspec spec/custom spec/services/conversations/assignment_service_spec.rb spec/models/concerns/auto_assignment_handler_spec.rb`
  - Expected: PASS
- [ ] **Step 5: Commit** with `feat(wfm): requeue an agent's open chats when they go away or offline`

### Task 4: Idle and live-SLA account settings (backend)

**Files:**
- Modify: `custom/app/models/custom/concerns/account.rb` (created in Task 1): `store_accessor :settings, :idle_away_timeout_minutes, :idle_away_reason_id, :sla_at_risk_threshold_percent, :sla_live_hit_rate_window_hours`
- Create: `custom/app/controllers/custom/api/v1/accounts_settings.rb`. It is prepended the same way enterprise's `accounts_settings.rb` is, and does `super + %i[idle_away_timeout_minutes idle_away_reason_id sla_at_risk_threshold_percent sla_live_hit_rate_window_hours]`.
- Modify: `app/models/concerns/account_settings_schema.rb:7-36`. Add the four keys:
  - `idle_away_timeout_minutes`: integer 1–240 or null
  - `idle_away_reason_id`: integer or null
  - `sla_at_risk_threshold_percent`: integer 1–99
  - `sla_live_hit_rate_window_hours`: integer 1–168

  Note it in FORK_NOTES.
- Test: `spec/custom/controllers/api/v1/accounts_settings_spec.rb`

**Interfaces:**
- Produces:
  - Settings readable at `account.settings['idle_away_timeout_minutes']` and the other keys. They appear in the existing account JSON (`_account.json.jbuilder` already returns `settings`).
  - `Account#fazaa_idle_enabled?` is true only when both idle keys are present and the reason is active.
  - `Account#sla_at_risk_threshold_percent` defaults to `20`; `Account#sla_live_hit_rate_window_hours` defaults to `24`.

- [ ] **Step 1: Write the failing spec**
  - An admin `PATCH /api/v1/accounts/:id` with `{idle_away_timeout_minutes: 10, idle_away_reason_id: r.id}` persists them.
  - `0`, `500` and `"abc"` for the timeout each return 422.
  - `fazaa_idle_enabled?` is false when the reason is inactive.
  - The defaults are 20 and 24 when unset.
- [ ] **Step 2: Run it and confirm it fails**
- [ ] **Step 3: Implement the accessors, settings allowlist overlay and schema keys**
- [ ] **Step 4: Run it, plus `spec/controllers/api/v1/accounts_controller_spec.rb`, and confirm they pass**
- [ ] **Step 5: Commit** with `feat(wfm): idle and live-SLA account settings`

### Task 5: Dashboard — Away in the status picker, plus the Away reasons settings page

**Files:**
- Modify: `app/javascript/dashboard/constants/globals.js:50` (`AVAILABILITY_STATUS_KEYS` gains `'away'`). Note it in FORK_NOTES.
- Modify: `components-next/sidebar/SidebarProfileMenuStatus.vue:28-62`. Show Away only when `fazaa_wfm` is on. Choosing Away opens `AwayReasonPicker` instead of saving straight away.
- Create: `components-next/sidebar/AwayReasonPicker.vue`, a modal listing the active reasons. Save stays disabled until one is selected, and it dispatches `updateAvailability({ availability: 'away', account_id, away_reason_id })`.
- Modify: `store/modules/auth.js:173` and `api/auth.js:72` to pass `away_reason_id` through. If the request fails, roll the optimistic update back and show the server's message.
- Create: `api/awayReasons.js` (`ApiClient('away_reasons', { accountScoped: true })`), `store/modules/awayReasons.js` (registered in `store/index.js`)
- Create: `routes/dashboard/settings/awayReasons/{awayReasons.routes.js,Index.vue,AwayReasonForm.vue}`, registered in `settings/settings.routes.js`. Meta: `{ featureFlag: FEATURE_FLAGS.FAZAA_WFM, permissions: ['administrator'] }`. The page supports list, add, rename, reorder (by position) and deactivate/reactivate. Copy the SLA settings page's layout.
- Modify: the dashboard i18n `en` and `ar` (new `AWAY_REASONS` namespace plus the `AVAILABILITY.AWAY` label), and the settings sidebar entry.
- Test: `store/modules/specs/awayReasons/{actions,getters,mutations}.spec.js`, `components-next/sidebar/specs/AwayReasonPicker.spec.js`, and an `auth` actions spec case

**Interfaces:**
- Consumes: the Task 1 REST API and the Task 2 availability API
- Produces:
  - Getter `awayReasons/getActive` → `[{id, name, position}]`, sorted by `position`
  - `auth/getCurrentUserAvailability` can now return `'away'`
  - The current user's `away_reason_name` is exposed on the current account_user for the status chip

- [ ] **Step 1: Write the failing Vitest specs**
  - Picker:
    - Save is disabled with no selection.
    - Selecting a reason and saving dispatches `updateAvailability` with that `away_reason_id`.
    - The cancel button dispatches nothing.
  - Store: fetch/create/update/deactivate mutations. `getActive` hides inactive reasons and sorts by position.
  - Auth: a failed away update rolls back to the previous availability.
- [ ] **Step 2: Run them and confirm they fail**
  - Run: `pnpm test -- app/javascript/dashboard/store/modules/specs/awayReasons app/javascript/dashboard/components-next/sidebar/specs`
  - Expected: FAIL
- [ ] **Step 3: Implement the constants, picker, store/api, settings page, i18n and sidebar entry**
- [ ] **Step 4: Run the specs, then `pnpm eslint` on the changed files, and confirm both pass**
- [ ] **Step 5: Manual check:** with the flag on in the dev seed account, choose Away, pick a reason and confirm the chip shows it. In Agents settings an admin sees the status. With the flag off, Away is hidden.
- [ ] **Step 6: Commit** with `feat(wfm): away reason picker and away reasons settings page`

### Task 6: Dashboard — idle detector and "Still there?" modal

**Files:**
- Create: `app/javascript/dashboard/composables/useIdleAway.js`, `app/javascript/dashboard/components-next/wfm/StillThereModal.vue`
- Modify: the dashboard root layout (`routes/dashboard/Dashboard.vue`, or whichever component wraps every authenticated page) to mount `useIdleAway()` and the modal once. Note it in FORK_NOTES.
- Create: `routes/dashboard/settings/account/components/IdleAway.vue` (based on `AutoResolve.vue`). It sets the timeout minutes and picks the idle reason from active reasons. It's shown only with `fazaa_wfm`. Register it in `settings/account/Index.vue`.
- Modify: dashboard i18n `en`/`ar` (`IDLE_AWAY` namespace)
- Test: `composables/specs/useIdleAway.spec.js`, `components-next/wfm/specs/StillThereModal.spec.js`

**Interfaces:**
- Consumes: account settings (Task 4), `updateAvailability` with `away_reason_id` (Task 5)
- Produces: `useIdleAway({ timeoutMinutes, reasonId, getAvailability, setAway, now = Date.now, storage = window.localStorage })` → `{ isPromptOpen: Ref<boolean>, secondsLeft: Ref<number>, confirmPresent(): void }`
  - **Activity events:** `mousemove`, `mousedown`, `keydown`, `wheel`, `touchstart` on `window`; `focus` on `window`; `visibilitychange` when the page becomes visible.
  - **Activity is throttled to one write per 5s** to `localStorage['fazaa:lastActivityAt']`. All tabs read that key, which together with the `storage` event keeps tabs in step (Review Focus 1).
  - **Disabled entirely** unless the account's `fazaa_idle_enabled?` is true and the current availability is `online` or `busy`.
  - **Prompt timing:** the prompt opens when `now - lastActivityAt >= timeoutMinutes * 60_000`, then counts down 60s.
    - `confirmPresent()` or any activity during the countdown closes the prompt and resets the timer.
    - At 0 it calls `setAway(reasonId)` once and closes the prompt.

- [ ] **Step 1: Write the failing Vitest specs** (fake timers, injected `now` and `storage`)
  - No prompt before the timeout. The prompt opens at exactly the timeout.
  - `confirmPresent` closes it and `setAway` is not called. Letting the 60s run out calls `setAway(reasonId)` exactly once.
  - Activity written to storage by another "tab" (writing the key directly) keeps the prompt from opening.
  - No timer runs when availability is `offline` or `away`, or when idle is disabled.
  - The modal shows `secondsLeft` and its button calls `confirmPresent`.
- [ ] **Step 2: Run them and confirm they fail**
  - Run: `pnpm test -- app/javascript/dashboard/composables/specs/useIdleAway.spec.js app/javascript/dashboard/components-next/wfm`
  - Expected: FAIL
- [ ] **Step 3: Implement the composable, modal, mount point and settings section**
- [ ] **Step 4: Run the specs and `pnpm eslint` on the changed files, and confirm both pass**
- [ ] **Step 5: Manual check:** set the timeout to 1 minute with two tabs open and type in tab A. Tab B doesn't prompt. Leave both idle; the prompt appears and after 60s the status becomes Away with the idle reason. Open chats requeue (Task 3).
- [ ] **Step 6: Commit** with `feat(wfm): idle detector with still-there prompt and auto-away`

### Task 7: SLA-Live endpoint

**Files:**
- Create: `custom/app/controllers/api/v1/accounts/live_sla_controller.rb`, `custom/app/services/fazaa/live_sla_board.rb`, `custom/app/views/api/v1/accounts/live_sla/index.json.jbuilder`
- Modify: `config/routes.rb`, adding `get 'reports/live_sla', to: 'live_sla#index'` inside the accounts scope. Note it in FORK_NOTES.
- Test: `spec/custom/services/fazaa/live_sla_board_spec.rb`, `spec/custom/controllers/api/v1/accounts/live_sla_controller_spec.rb`

**Interfaces:**
- Consumes:
  - Enterprise `AppliedSla` (`sla_status` active/active_with_misses; `frt_due_at`/`nrt_due_at`/`rt_due_at`)
  - `SlaPolicy` thresholds (seconds)
  - `Account#sla_at_risk_threshold_percent` and `#sla_live_hit_rate_window_hours` (Task 4)
- Produces:
  - `GET /api/v1/accounts/:account_id/reports/live_sla`
    - **Filters:** `inbox_id`, `team_id`, `assignee_id`, `label`, `sla_policy_id`, `cr_code`, `country`. The last two match `conversations.custom_attributes ->> 'cr_code'` / `'country'`.
    - **Access:** admin only (same rule as `applied_slas#index`). Returns 403 unless both `sla` and `fazaa_sla_live` are on (Review Focus 5).
  - Response:
    ```json
    { "summary": { "breached": 3, "at_risk": 5, "hit_rate": 0.87, "window_hours": 24, "at_risk_percent": 20 },
      "rows": [ { "conversation_id": 1, "display_id": 42, "inbox": {"id":1,"name":"…"}, "assignee": {"id":7,"name":"…"} | null,
                  "sla_policy": {"id":2,"name":"…"}, "labels": ["…"], "custom_attributes": {"cr_code":"CR124"},
                  "timers": { "frt": {"state":"at_risk","due_at":1731400000,"threshold_seconds":300},
                              "nrt": {"state":"na"}, "rt": {"state":"breached","due_at":…,"threshold_seconds":…} },
                  "worst_state": "breached" } ],
      "server_time": 1731399900 }
    ```
  - `Fazaa::LiveSlaBoard.new(account:, filters:, now: Time.current).call` → the hash above. Rows are sorted by `worst_state` (breached, at_risk, on_track), then by the earliest open `due_at`.
  - **Rows:** only open, pending or snoozed conversations whose `applied_sla.sla_status` is `active` or `active_with_misses`.
  - **Timer state:**
    - `na`: the timer doesn't apply, or the policy threshold is nil.
      - FRT applies until `first_reply_created_at` is set.
      - NRT applies while `waiting_since` is set.
      - RT applies while the conversation isn't resolved.
    - `breached`: `due_at <= now`, or a `SlaEvent` of that type exists for the applied SLA.
    - `at_risk`: `(due_at - now) < threshold_seconds * pct / 100`.
    - `on_track`: otherwise.
  - **Summary:**
    - `breached` / `at_risk` count rows by `worst_state`.
    - `hit_rate = hit / (hit + missed + active_with_misses)` over this account's `applied_slas` with `updated_at >= now - window_hours`. It's `null` when the denominator is 0.

- [ ] **Step 1: Write the failing specs** (`travel_to` for time, the enterprise `applied_sla`/`sla_policy`/`sla_event` factories, `account.enable_features!('sla', 'fazaa_sla_live')`)
  - FRT threshold 300s, conversation created 250s ago → `at_risk` (50s left < 60s). 200s ago → `on_track`. 301s ago → `breached`.
  - FRT after the first reply → `na`.
  - An existing `frt` SlaEvent → `breached` even when `due_at` is in the future.
  - Resolved conversation and `hit` applied SLA → excluded from rows.
  - Filters: `inbox_id` and `cr_code` each narrow the rows.
  - `hit_rate`: 3 hit, 1 missed in the window, plus 1 hit outside the window → `0.75`. No data → `null`.
  - With `pct` set to 10, the 250s case → `on_track`.
  - Controller: agent → 401/403. `sla` off → 403. Admin → 200, with `summary` and `rows` present.
- [ ] **Step 2: Run them and confirm they fail**
  - Run: `bundle exec rspec spec/custom/services/fazaa/live_sla_board_spec.rb spec/custom/controllers/api/v1/accounts/live_sla_controller_spec.rb`
  - Expected: FAIL
- [ ] **Step 3: Implement the service, controller, view and route**
  - Preload `applied_sla: :sla_policy`, `inbox`, `assignee`, `sla_events` and labels to avoid N+1.
  - Due-at values come from the `AppliedSla` methods, which already handle business hours. Don't recompute them.
- [ ] **Step 4: Run the specs, plus `spec/enterprise/controllers/api/v1/accounts/applied_slas_controller_spec.rb`, and confirm they pass**
- [ ] **Step 5: Commit** with `feat(sla-live): live SLA board endpoint`

### Task 8: SLA-Live wallboard page

**Files:**
- Create: `app/javascript/dashboard/api/liveSla.js`, `store/modules/liveSla.js` (registered), `routes/dashboard/settings/reports/LiveSla.vue`, `components-next/sla-live/{LiveSlaSummary.vue,LiveSlaTable.vue,LiveSlaFilters.vue}`
- Modify: `routes/dashboard/settings/reports/reports.routes.js` (next to `SLAReports` at ~L159). The route is `live_sla`, with meta `{ featureFlag: FEATURE_FLAGS.FAZAA_SLA_LIVE, permissions: <same as SLA reports> }`. Also add the reports sidebar entry. Note both in FORK_NOTES.
- Modify: dashboard i18n `en`/`ar` (`LIVE_SLA` namespace)
- Test: `store/modules/specs/liveSla/*.spec.js`, `components-next/sla-live/specs/LiveSlaTable.spec.js`

**Interfaces:**
- Consumes: the Task 7 endpoint
- Produces:
  - **Page:** a summary strip (breached, at risk, hit rate with its window), filters (inbox, team, assignee, label, SLA policy, CR code, country), and the table.
  - **Each row** shows a per-timer chip (on track / at risk / breached / –) with a live countdown worked out from `due_at - (server_time + elapsed since fetch)`. That stops a wrong local clock from distorting the countdown.
  - **Clicking a row** opens the conversation (`conversation_through_inbox` / the standard conversation route) in the same tab.
  - **Polling:** every 5s while the page is visible, using the current filters. Polling pauses on `visibilitychange` hidden and stops when you leave the page. A failed poll keeps the last data and shows a small "stale since hh:mm:ss" badge.

- [ ] **Step 1: Write the failing Vitest specs**
  - Store: `fetch` passes the filters as query params. A fetch error keeps the previous rows and sets `staleSince`.
  - Table:
    - Breached rows render first.
    - A chip at `due_at = server_time + 30` shows `00:30` and `at risk` classes.
    - Advancing fake timers by 31s with no refetch flips it to breached.
    - Clicking a row calls `router.push` with that conversation.
  - Page: polling starts on mount and stops on unmount. A hidden document triggers no fetch.
- [ ] **Step 2: Run them and confirm they fail**
  - Run: `pnpm test -- app/javascript/dashboard/store/modules/specs/liveSla app/javascript/dashboard/components-next/sla-live`
  - Expected: FAIL
- [ ] **Step 3: Implement the api, store, components, route, sidebar entry and i18n**
- [ ] **Step 4: Run the specs and `pnpm eslint` on the changed files, and confirm both pass**
- [ ] **Step 5: Manual check:** set up an SLA policy with FRT of 2 minutes, create a conversation and watch the chip go from on track to at risk to breached without reloading. Reply, and the FRT chip becomes `–` within 5s. Filter by inbox.
- [ ] **Step 6: Commit** with `feat(sla-live): live SLA wallboard page`

---

## Done when (spec, Wave 5a)

- An agent cannot go Away without a reason, and an admin can create, edit and deactivate reasons (Tasks 1, 2, 5).
- When idle timeout is configured, it prompts and moves the agent to Away (Tasks 4, 6).
- Away/offline requeues open chats within ~5s (Task 3, `high` queue).
- The Live SLA page shows at-risk and breached open chats with live refresh and drill-down (Tasks 7, 8).
- `custom/FORK_NOTES.md` lists every upstream file touched.
