# Fork notes

Every upstream file touched by the Fazaa fork, one line each: path, change, and why there was no hook.

- `config/application.rb`: adds `custom/` to eager-load paths, view paths and initializers, mirroring the enterprise lines; no hook exists for loading a third extension directory.
- `config/features.yml`: appends `fazaa_wfm` and `fazaa_sla_live` flags; feature flags are defined only in this file.
- `app/javascript/dashboard/featureFlags.js`: mirrors the two new flags in `FEATURE_FLAGS`; the frontend flag list is a static constant with no extension point.
- `config/routes.rb`: adds `resources :away_reasons` next to `sla_policies`; routes are a single file with no extension hook.
- `db/migrate/20261112100000_create_away_reasons.rb`, `db/schema.rb`: new migration and generated schema for `away_reasons`; migrations live only in `db/migrate`.
- `app/models/account_user.rb`: adds `away: 3` to the `availability` enum; enum values cannot be extended from an overlay concern.
- `app/controllers/api/v1/profiles_controller.rb`, `app/controllers/api/v1/accounts/agents_controller.rb`: permit `:away_reason_id`, preload `account_users: :away_reason` in the agents query and wrap the update in a transaction; controllers have no hook.
- `app/views/api/v1/models/_user.json.jbuilder`, `app/views/api/v1/models/_agent.json.jbuilder`: emit `away_reason_id` and `away_reason_name`; jbuilder partials have no extension point.
- `config/locales/en.yml`, `config/locales/ar.yml`: add `errors.account_user.away_reason_required`; locale files are loaded from `config/locales` only.
- `db/migrate/20261112100100_add_away_reason_to_account_users.rb`, `db/schema.rb`: new column and `agent_availability_events` table; migrations live only in `db/migrate`.
- `config/locales/en.yml`, `config/locales/ar.yml`: also add `conversations.activity.assignee.requeued_on_away` and `requeued_status`; locale files are loaded from `config/locales` only.
- `app/models/concerns/account_settings_schema.rb`: adds `idle_away_timeout_minutes`, `idle_away_reason_id`, `sla_at_risk_threshold_percent`, `sla_live_hit_rate_window_hours` to `SETTINGS_PARAMS_SCHEMA`; the schema is a single constant with no extension point.
- `app/javascript/dashboard/constants/globals.js`: appends `'away'` to `AVAILABILITY_STATUS_KEYS`; the status list is a static constant with no extension point.
- `app/javascript/dashboard/components-next/sidebar/SidebarProfileMenuStatus.vue`: adds the flag-gated Away status, its colour, the reason chip and a request to open the `AwayReasonPicker`; the status list is hard-coded in this component.
- `app/javascript/dashboard/components-next/avatar/Avatar.vue`: adds the `away` status dot colour; `STATUS_CLASSES` is a local constant.
- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`: adds the flag-gated "Away reasons" settings entry and mounts the `AwayReasonPicker` modal outside the profile dropdown; the settings menu is a hard-coded list.
- `app/javascript/dashboard/store/modules/auth.js`, `app/javascript/dashboard/store/mutation-types.js`: `updateAvailability` rethrows the server message when Away fails, new `getCurrentUserAwayReasonName` getter, presence events clear/refresh the away reason, and new away-reason mutation types; store modules and mutation types are single files.
- `app/javascript/dashboard/store/index.js`: registers the `awayReasons` module; modules are listed explicitly.
- `app/javascript/dashboard/routes/dashboard/settings/settings.routes.js`: registers the away reasons routes; settings routes are listed explicitly.
- `app/javascript/dashboard/i18n/locale/en/index.js`, `app/javascript/dashboard/i18n/locale/ar/index.js`, `app/javascript/dashboard/i18n/locale/en/settings.json`, `app/javascript/dashboard/i18n/locale/ar/settings.json`: import the `awayReasons.json` namespace and add `STATUS.AWAY` and `SIDEBAR.AWAY_REASONS`; locale indexes and settings.json are the only loaders.
- `app/javascript/dashboard/routes/dashboard/settings/agents/EditAgent.vue`: shows a disabled "Away" option when the agent is away and omits `availability` from the update payload in that case; the status list is hard-coded here.
- `app/javascript/dashboard/routes/dashboard/Dashboard.vue`: mounts the flag-gated `IdleAwayWatcher` once in the authenticated root layout; the layout has no slot or hook for extra global components.
- `app/javascript/dashboard/routes/dashboard/settings/account/Index.vue`: renders the flag-gated `IdleAway` settings section; the account settings page is a hard-coded list of sections.
- `app/javascript/dashboard/i18n/locale/en/index.js`, `app/javascript/dashboard/i18n/locale/ar/index.js`: import the `idleAway.json` namespace; locale indexes are the only loaders.
- `config/routes.rb`: adds `get 'reports/live_sla', to: 'live_sla#index'` in the v1 accounts scope for the live SLA board; routes are a single file with no extension hook.
- `app/javascript/dashboard/routes/dashboard/settings/reports/reports.routes.js`: adds the `live_sla_reports` route (flag `fazaa_sla_live`, same permissions as SLA reports); routes are listed explicitly.
- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`: adds the "Live SLA" reports entry shown only when both `sla` and `fazaa_sla_live` are on; the reports menu is a hard-coded list.
- `app/javascript/dashboard/store/index.js`, `app/javascript/dashboard/store/mutation-types.js`: register the `liveSla` module and its mutation types; store modules and mutation types are single files.
- `app/javascript/dashboard/i18n/locale/en/index.js`, `app/javascript/dashboard/i18n/locale/ar/index.js`: import the `liveSla.json` namespace; locale indexes are the only loaders.
- `app/javascript/dashboard/helper/agentHelper.js`: `getSortedAgentsByAvailability` lists `away` agents after busy and before offline; the sort order is a hard-coded list.
- `app/javascript/dashboard/store/modules/agents.js`, `app/javascript/dashboard/routes/dashboard/settings/reports/constants.js`, `app/javascript/dashboard/i18n/locale/en/report.json`, `app/javascript/dashboard/i18n/locale/ar/report.json`: `getAgentStatus` counts `away` agents and the overview "Agent status" card gets its `AWAY` label; the status counts, metric map and labels are static.
- `app/javascript/dashboard/components/widgets/conversation/TagAgents.vue`: adds the `away` availability label to the mention picker; the label map is a local constant.
- `app/javascript/dashboard/helper/auditlogHelper.js`: maps availability `3` to `'away'` in audit logs; the enum mapping is a local constant.
- `app/javascript/dashboard/components-next/sidebar/SidebarProfileMenuStatus.vue`: also keeps Away shown as the active status when the current value is `away` with `fazaa_wfm` off (it stays unselectable); the status list is hard-coded in this component.
- `swagger/definitions/resource/agent.yml`, `swagger/definitions/request/agent/create_payload.yml`, `swagger/definitions/request/agent/update_payload.yml`, `swagger/swagger.json`, `swagger/tag_groups/*_swagger.json`: add `away` to the agent availability enums (built JSON regenerated with `rake swagger:build`, keeping only the `away` hunks); the API docs are generated from these files only.
- `app/javascript/dashboard/helper/specs/agentHelper.spec.js`, `app/javascript/dashboard/store/modules/specs/agents/getters.spec.js`, `app/javascript/dashboard/helper/specs/auditlogHelper.spec.js`: extended with away-agent cases; upstream specs cover these upstream helpers.
