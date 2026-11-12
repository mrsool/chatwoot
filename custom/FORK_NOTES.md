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
