# Fazaa Phase 5 — Wave 5b (Compensation caps) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ops edit MBO's buyer reimbursement caps in Chatwoot (Settings → Compensation caps). MBO enforces them, and falls back to its current Fallout values for any cap left blank or when Chatwoot can't be reached.

**Architecture:**
- **Chatwoot:** a singleton row per account in a new `compensation_cap_settings` table under `custom/`. It is exposed as `GET`/`PATCH /api/v1/accounts/:id/compensation_caps` for admins. Changes are audited with the `audited` gem. Everything sits behind the `fazaa_compensation_caps` flag.
- **MBO:** reads the caps through `Chatwoot::Client`, using fast timeouts and a 60s `Rails.cache`. A Fallout kill switch, `chatwoot_compensation_caps`, turns this off. MBO uses the caps inside the three existing `Bots::Orders::*LimitReachedService` classes.

**Tech Stack:** Chatwoot fork (Rails 7.2, Vue 3, Vitest); mrsool-backend (Rails, dry-monads services, Fallout flags, WebMock).

**Spec:** Confluence "Chatwoot Integration" §5.4 (copy at `docs/superpowers/specs/2026-11-12-fazaa-phase5-platform-capabilities.md`). The spec's "lateness thresholds / compensation amounts" don't exist in MBO. The scope we agreed on 13 Nov (option 1) is to move MBO's *existing* buyer reimbursement caps, which are now Fallout flags in `config/fallout/support.yml:115-147`, into Chatwoot. This plan is that scope.

## Global Constraints

- **Repos and branches:**
  - Chatwoot: worktree `/Users/siddharth/mrsool/chatwoot-faz-10-5b`, branch `feat/FAZ-10-wave-5b`, stacked on `feat/FAZ-10-wave-5a`.
  - MBO: worktree `/Users/siddharth/mrsool/mrsool-backend-caps`, branch `feat/faz-compensation-caps`, based on `origin/develop`.
- **Chatwoot fork rules:**
  - New backend code goes under `custom/`. Never edit `enterprise/`.
  - Add one line to `custom/FORK_NOTES.md` for every upstream file you touch.
  - Run commands and commits inside docker: `/Users/siddharth/mrsool/chatwoot-faz-10/.superpowers/sdd/2026-11-12-fazaa-phase5-wave5a/run sh -c 'cd /Users/siddharth/mrsool/chatwoot-faz-10-5b && <cmd>'`.
  - Run frontend tests only on the spec files you name explicitly, never on a whole directory.
  - The app must still boot with `enterprise/` deleted (FOSS CI job).
- **MBO rules:**
  - Follow `CLAUDE.md`: short comments that explain why, and never hard-delete records.
  - Run specs with `make rspec SPEC_PATH=<paths>` from the MBO worktree (compose project `mrsool-backend-test`).
- **Commit messages:**
  - Chatwoot: `feat(caps): … [FAZ-2xx]`.
  - MBO: `FAZ-2xx: <sentence>`.
  - Every commit message ends with `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.
- **The cap contract.** The column names, the JSON keys and MBO's keys are identical. Every field is nullable, and null means "use MBO's Fallout value".

  | Key | Type | Range | MBO Fallout flag it overrides |
  |---|---|---|---|
  | `bad_grade_value_limit` | decimal(10,2) → JSON number | 0..100000 | `bad_grade_customer_reimbursement_limit` |
  | `at_risk_value_limit` | same | 0..100000 | `at_risk_customer_reimbursement_limit` |
  | `valuable_value_limit` | same | 0..100000 | `valuable_customer_reimbursement_limit` |
  | `per_order_count_limit` | integer | 0..100 | `customer_allowed_reimbursements_per_order` |
  | `bad_grade_window_count_limit` | integer | 0..1000 | `bad_grade_customer_reimbursement_last30d_count_limit` |
  | `at_risk_window_count_limit` | integer | 0..1000 | `at_risk_customer_reimbursement_last30d_count_limit` |
  | `valuable_window_count_limit` | integer | 0..1000 | `valuable_customer_reimbursement_last30d_count_limit` |
  | `vip_window_count_limit` | integer | 0..1000 | `vip_customer_reimbursement_last30d_count_limit` |
  | `window_days` | integer | 1..365 | hardcoded `30.days` |

- **Unchanged behaviour:**
  - VIP has no value limit.
  - An unknown grade counts as limit reached.
  - Value limits are compared with the raw item sum, with no currency conversion, the same as today.

## Review Focus

1. **Chatwoot down or slow while a reimbursement runs.** MBO must fall back to Fallout within about 2s. One failure must not slow down the following calls: cache the empty result for 30s.
2. **A cap cleared back to blank.** PATCH with `""` or `null` stores NULL, and MBO falls back to Fallout. It must never read the cap as 0, which would block every reimbursement.
3. **Decimal serialisation.** Value limits must reach MBO as JSON numbers, never strings like `"30.0"`.
4. **The kill switch is off by default.** With `chatwoot_compensation_caps` off, MBO makes no HTTP call and behaves exactly as it does today.
5. **Access.** Only admins can PATCH. The API returns 401 when the flag is off. MBO's token must belong to an administrator of the account (a deploy note, not code).

---

### Task 1: Chatwoot caps store and admin API [FAZ-227]

**Files:**
- Create:
  - `db/migrate/20261113100000_create_compensation_cap_settings.rb`
  - `custom/app/models/compensation_cap_setting.rb`
  - `custom/app/policies/compensation_cap_setting_policy.rb`
  - `custom/app/controllers/api/v1/accounts/compensation_caps_controller.rb`
  - `custom/app/views/api/v1/accounts/compensation_caps/show.json.jbuilder`
  - `custom/app/views/api/v1/accounts/compensation_caps/update.json.jbuilder`
  - `custom/app/views/api/v1/models/_compensation_cap_setting.json.jbuilder`
- Modify:
  - `db/schema.rb`
  - `config/routes.rb` (next to `resources :away_reasons`)
  - `config/features.yml` (append after `fazaa_sla_live`)
  - `app/javascript/dashboard/featureFlags.js` (`FAZAA_COMPENSATION_CAPS: 'fazaa_compensation_caps'`)
  - `spec/models/account_spec.rb` (`feature_fazaa_compensation_caps: 1 << 12`)
  - `custom/FORK_NOTES.md`
- Test:
  - `spec/custom/models/compensation_cap_setting_spec.rb`
  - `spec/custom/controllers/api/v1/accounts/compensation_caps_controller_spec.rb`

**Interfaces:**
- Produces:
  - `CompensationCapSetting.for(account) -> CompensationCapSetting`. Calls `find_or_initialize_by(account:)`; the record is unsaved until the first PATCH.
  - `CompensationCapSetting::CAP_FIELDS`: the 9 contract keys as symbols.
  - `GET /api/v1/accounts/:account_id/compensation_caps` returns `{ payload: { <9 keys>, updated_at: iso8601|null, updated_by: { id, name }|null } }`.
  - `PATCH` with body `{ compensation_caps: { <any of 9 keys> } }` returns the same shape. Validation errors return 422 `{ message, attributes }`, following the AwayReasons controller.

Steps:

- [ ] **Step 1: Write the failing specs.**

  Model spec:
  - Each range in the contract is validated:
    - `-1` is invalid;
    - the upper bound + 1 is invalid;
    - `nil` is valid for every key;
    - `window_days: 0` is invalid.
  - The count fields reject non-integers (`1.5`).
  - `belongs_to :account`.
  - `account_id` is unique (a second row for the same account is invalid).
  - `CompensationCapSetting.for(account)` returns the existing row when there is one, and an unsaved row with all caps nil when there isn't.

  Request spec, with the account's `fazaa_compensation_caps` flag enabled:
  1. An admin GETs with no row and gets 200, all 9 keys `nil`, `updated_by: nil`.
  2. An admin PATCHes `{ at_risk_value_limit: 30, valuable_value_limit: '50.5', vip_window_count_limit: 10, window_days: 30 }`. The response is 200 and `response.parsed_body['payload']['valuable_value_limit'] == 50.5` (a JSON number, `be_a(Float)`). `updated_by.id` is the admin. A second GET returns the same values.
  3. An admin PATCHes `{ at_risk_value_limit: '' }` after a value was set, and it persists as nil.
  4. An admin PATCHes `{ window_days: 0 }` and gets 422.
  5. An agent GET or PATCH gets 401.
  6. With the flag off, an admin GET gets 401.
  7. `api_access_token` header auth works: GET with the admin's `access_token.token` in an `api_access_token` header returns 200. This is MBO's path.
  8. Audit: when `ChatwootApp.enterprise?`, a PATCH creates an `Enterprise::AuditLog` with `auditable_type: 'CompensationCapSetting'`, `associated: account`, and `audited_changes` containing `at_risk_value_limit`. Guard the example with `if: ChatwootApp.enterprise?`.

- [ ] **Step 2: Run them; they fail.**
  ```
  run sh -c 'cd /Users/siddharth/mrsool/chatwoot-faz-10-5b && RAILS_ENV=test bundle exec rspec spec/custom/models/compensation_cap_setting_spec.rb spec/custom/controllers/api/v1/accounts/compensation_caps_controller_spec.rb'
  ```

- [ ] **Step 3: Implement.**
  - **Migration.** Follow `20261112100000_create_away_reasons.rb`:
    - `t.references :account, null: false, index: false`, no DB foreign key;
    - the 9 nullable columns: value limits `decimal precision: 10, scale: 2`, the rest `integer`;
    - `t.bigint :updated_by_id`, `t.timestamps`;
    - a unique index `index_compensation_cap_settings_on_account_id`.
    - Regenerate `db/schema.rb`, keeping only this table's hunk.
  - **Model:**
    - `belongs_to :account` and `belongs_to :updated_by, class_name: 'User', optional: true`.
    - Validations from the contract: `numericality` with `allow_nil: true`, and `only_integer` for the counts.
    - `audited associated_with: :account, except: %i[created_at updated_at updated_by_id] if ChatwootApp.enterprise?`. The audit class is `Enterprise::AuditLog` (`config/initializers/audited.rb`), so an unconditional `audited` breaks the FOSS boot.
  - **Policy:** `show?` and `update?` are true only for `@account_user.administrator?`.
  - **Controller:**
    - Copy the shape of `AwayReasonsController`. Raise `Pundit::NotAuthorizedError` unless `Current.account.feature_enabled?('fazaa_compensation_caps')`.
    - Call `authorize` on the record.
    - In `update`, assign the permitted params with blank strings turned to nil, set `updated_by: Current.user`, then `save!`. Rescue `ActiveRecord::RecordInvalid` and return 422.
  - **Partial.** Render the value limits with `&.to_f` and the counts as integers.
  - **Route:** `resource :compensation_caps, only: [:show, :update]` in the v1 accounts scope.

- [ ] **Step 4: Run the specs from Step 2, plus the existing specs.**
  - Expected: all pass, including `spec/custom` and `spec/models/account_spec.rb`.
  - Then run rubocop on the changed Ruby files.
  - Then the FOSS boot check: copy the worktree without `enterprise/`, `spec/enterprise`, `node_modules` and `.git`, and run `bundle exec rails runner 'puts CompensationCapSetting.new.valid?'` with `RAILS_ENV=test`. Expected output: `true`.

- [ ] **Step 5: Add a FORK_NOTES line for each upstream file touched, then commit.**
  ```
  feat(caps): compensation caps store and admin API behind fazaa_compensation_caps [FAZ-227]
  ```

### Task 2: Chatwoot Settings → Compensation caps page [FAZ-228]

**Files:**
- Create:
  - `app/javascript/dashboard/api/compensationCaps.js`
  - `app/javascript/dashboard/routes/dashboard/settings/compensationCaps/compensationCaps.routes.js`
  - `app/javascript/dashboard/routes/dashboard/settings/compensationCaps/Index.vue`
  - `app/javascript/dashboard/i18n/locale/en/compensationCaps.json`
  - `app/javascript/dashboard/i18n/locale/ar/compensationCaps.json`
- Modify:
  - `settings/settings.routes.js`
  - `components-next/sidebar/Sidebar.vue` (settings entry gated by the flag, after "Away reasons")
  - `i18n/locale/{en,ar}/index.js`
  - `i18n/locale/{en,ar}/settings.json` (`SIDEBAR.COMPENSATION_CAPS`)
  - `helper/auditlogHelper.js` (`compensationcapsetting:create` and `compensationcapsetting:update` translation keys; an `EVENT_TYPE_GROUPS` entry)
  - `i18n/locale/{en,ar}/auditLogs.json`
  - `custom/FORK_NOTES.md`
- Test:
  - `app/javascript/dashboard/routes/dashboard/settings/compensationCaps/specs/Index.spec.js`
  - `app/javascript/dashboard/helper/specs/auditlogHelper.spec.js` (extend it)

**Interfaces:**
- Consumes the Task 1 API.
- `compensationCaps.js` exports a `CompensationCapsAPI` with `get()` and `update(payload)`. It is account-scoped and follows `api/awayReasons.js`, but uses the singular resource path `compensation_caps`.

Steps:

- [ ] **Step 1: Write the failing specs.** Mount `Index.vue` with the API mocked.
  1. It loads the caps and fills each of the 9 inputs; a nil cap shows as an empty input with the placeholder `COMPENSATION_CAPS.FORM.USE_DEFAULT`.
  2. On submit it calls `update` with numbers for filled fields and `null` for cleared ones.
  3. When `window_days` is 0 or a count is 1.5, it shows an inline error and does not call `update`.
  4. The "last changed by {name} on {date}" line renders when `updated_by` is present.
  5. On success it shows a success alert. On failure it shows an alert with the server message.

  `auditlogHelper` spec: `compensationcapsetting:update` maps to `AUDIT_LOGS.COMPENSATION_CAPS.EDIT`.
- [ ] **Step 2: Run them; they fail.**
  ```
  run sh -c 'cd /Users/siddharth/mrsool/chatwoot-faz-10-5b && pnpm exec vitest run <the two spec paths>'
  ```
- [ ] **Step 3: Implement.**
  - **Page:**
    - Use `<script setup>` in the `IdleAway.vue` style, with `WithLabel`, `NextButton`, `useAlert` and `useI18n`.
    - Three sections:
      - "Max value per reimbursement": the bad, at-risk and valuable grades, plus a VIP row that reads "Unlimited" as text and has no input;
      - "Max reimbursements per order";
      - "Max reimbursements per window": the four grades plus window days.
    - Helper text under the value section: "Compared against the reimbursed item total in the order's currency."
  - **Route:** meta `{ featureFlag: FEATURE_FLAGS.FAZAA_COMPENSATION_CAPS, permissions: ['administrator'] }`.
  - **Arabic:** a full translation, not English placeholders.
  - **Audit log:** the audit entry text is "{agentName} updated compensation caps", with the same wording for create.
- [ ] **Step 4: Run them again; they pass. Then run eslint on the changed files.**
- [ ] **Step 5: FORK_NOTES, then commit.**
  ```
  feat(caps): Settings → Compensation caps page and audit log labels [FAZ-228]
  ```

### Task 3: MBO reads caps from Chatwoot [FAZ-229]

**Files (MBO worktree):**
- Modify:
  - `config/fallout/support.yml` (append `chatwoot_compensation_caps: { type: boolean, default: false }`)
  - `app/services/chatwoot/client.rb`
- Create:
  - `app/services/chatwoot/compensation_caps.rb`
- Test:
  - `spec/services/chatwoot/client_spec.rb` (extend it)
  - `spec/services/chatwoot/compensation_caps_spec.rb`

**Interfaces:**
- Produces:
  - `Chatwoot::Client#get_compensation_caps -> Hash`. It is the parsed `payload`, sent as `GET /api/v1/accounts/<account_id>/compensation_caps`. It raises `Chatwoot::Client::Error` on a non-2xx status, a timeout or a connection failure.
  - `Chatwoot::CompensationCaps.current -> Chatwoot::CompensationCaps`, a value object. Its readers return `Numeric` or `nil`:
    - `value_limit(grade)` for `"bad"`, `"at_risk"` and `"valuable"`; nil otherwise;
    - `window_count_limit(grade)` for `"bad"`, `"at_risk"`, `"valuable"` and `"vip"`;
    - `per_order_count_limit`;
    - `window_days`.
  - Grade strings are the `Users::SupportCustomerGrading::*_GRADE` constants.

Steps:

- [ ] **Step 1: Write the failing specs (WebMock).**

  Client spec:
  - It GETs `compensation_caps` with the `Api-Access-Token` header and returns the payload hash.
  - On a 500 it raises `Error` with `status: 500`, after **one** request (no retry).
  - A timeout (`to_timeout`) raises `Error`.

  CompensationCaps spec:
  1. With the switch off, it makes no request (`expect(a_request(:any, //)).not_to have_been_made`) and every reader returns nil.
  2. With the switch on and a stubbed payload, the readers return the values, and `value_limit('at_risk')` is `30.0`.
  3. Two `current` calls within 60s make one request (memory cache store in the spec).
  4. On a Chatwoot error it returns all-nil readers, calls `Sentry.capture_exception` once, and a second call within 30s makes no new request.
  5. An unconfigured client (blank settings) gives all-nil readers with no request.
- [ ] **Step 2: Run them; they fail.**
  ```
  make rspec SPEC_PATH="spec/services/chatwoot/client_spec.rb spec/services/chatwoot/compensation_caps_spec.rb"
  ```
- [ ] **Step 3: Implement.**
  - **`Chatwoot::Client`:**
    - `get_compensation_caps` goes through a memoised `fast_connection`. It is the same base URL, headers and JSON middleware, with `open_timeout: 1` and `timeout: 2`, and **no retry middleware**.
    - It reuses the error handling of `request`, refactoring that into a private helper that takes the connection.
    - It returns `body['payload']`.
  - **`Chatwoot::CompensationCaps`:**
    - `include Chatwoot::BaseConnection`.
    - `Rails.cache.fetch('chatwoot:compensation_caps:v1', expires_in: 60.seconds)` holds the hash.
    - On `Chatwoot::Client::Error`: call `log_chatwoot_error`, then `Rails.cache.write(key, {}, expires_in: 30.seconds)` and use `{}`.
    - Keys are symbolised. The switch is read with `Fallout[:support].chatwoot_compensation_caps.enabled?`.
- [ ] **Step 4: Run them again; they pass. Then run rubocop on the changed files.**
- [ ] **Step 5: Commit.** `FAZ-229: read compensation caps from Chatwoot with a short cache and a kill switch`

### Task 4: MBO enforces Chatwoot caps [FAZ-230]

**Files (MBO worktree):**
- Modify, all under `app/services/bots/orders/`:
  - `buyer_reimbursement_value_limit_reached_service.rb`
  - `buyer_reimbursement_per_order_count_limit_reached_service.rb`
  - `buyer_reimbursement_last30d_count_limit_reached_service.rb`
- Test: the three matching specs in `spec/services/bots/orders/`.

**Interfaces:**
- Consumes the Task 3 `Chatwoot::CompensationCaps.current`.
- Nothing new is produced. Return values, error codes and endpoints don't change.

Steps:

- [ ] **Step 1: Write the failing specs.** Add these to each service spec. Stub `Chatwoot::CompensationCaps.current` with an `instance_double` that returns the readers.
  - **Value limit:**
    - Chatwoot `at_risk` 30.0 with Fallout 100.0: a value of 31 reaches the limit and 30 doesn't.
    - Chatwoot nil: Fallout is used.
    - VIP never reaches the limit, whatever the caps.
    - An unknown grade reaches the limit.
  - **Per order:** Chatwoot `per_order_count_limit` 2 with Fallout 1 and one prior reimbursement: the limit is not reached. With Chatwoot nil, Fallout 1 applies.
  - **Window count:**
    - `window_days` 7 with one reimbursement 10 days old and `at_risk` limit 1: not reached. The same reimbursement 3 days old: reached.
    - `window_days` nil: 30 days is used.
    - `vip_window_count_limit` nil: Fallout is used.
  - The existing examples that stub Fallout must keep passing unchanged. In those, stub `CompensationCaps.current` to all-nil in a shared `before`.
- [ ] **Step 2: Run them; they fail.**
  ```
  make rspec SPEC_PATH=spec/services/bots/orders
  ```
- [ ] **Step 3: Implement.**
  - In each service, read the limit as `caps.<reader> || Fallout[:support].<flag>.value`, and keep the existing `.to_i` on counts.
  - The window becomes `(caps.window_days || 30).days.ago`.
  - Memoise `caps` with `memoize def caps = Chatwoot::CompensationCaps.current`.
  - Keep the unknown-grade fail-closed check *before* any caps lookup.
- [ ] **Step 4: Run them again; they pass.** Also run `spec/requests/api/bots/v1/orders_spec.rb`, `spec/requests/api/bots/v1/users_spec.rb` and `spec/services/bots/orders/buyer_reimbursement_service_spec.rb`, then rubocop.
- [ ] **Step 5: Commit.** `FAZ-230: enforce Chatwoot compensation caps in buyer reimbursement limits, falling back to Fallout`

## Done when

- An admin edits caps in Chatwoot, a non-admin can't, and every change is audited.
- With MBO's switch on, the three limit checks use the Chatwoot values. A blank cap, a Chatwoot outage, or the switch turned off all fall back to the Fallout values within about 2s.
- **Deploy notes for the PRs:**
  - `Settings.chatwoot.api_access_token` must belong to an administrator of the Chatwoot account.
  - Turn on `fazaa_compensation_caps` in Chatwoot, enter the current prod Fallout values, then turn on `chatwoot_compensation_caps` in MBO.
