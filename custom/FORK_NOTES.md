# Fork notes

Every upstream file touched by the Fazaa fork, one line each: path, change, and why there was no hook.

- `config/application.rb`: adds `custom/` to eager-load paths, view paths and initializers, mirroring the enterprise lines; no hook exists for loading a third extension directory.
- `config/features.yml`: appends `fazaa_wfm` and `fazaa_sla_live` flags; feature flags are defined only in this file.
- `app/javascript/dashboard/featureFlags.js`: mirrors the two new flags in `FEATURE_FLAGS`; the frontend flag list is a static constant with no extension point.
- `config/routes.rb`: adds `resources :away_reasons` next to `sla_policies`; routes are a single file with no extension hook.
- `db/migrate/20261112100000_create_away_reasons.rb`, `db/schema.rb`: new migration and generated schema for `away_reasons`; migrations live only in `db/migrate`.
