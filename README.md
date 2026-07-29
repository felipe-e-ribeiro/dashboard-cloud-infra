# dashboard-cloud (Helm chart)

Deploys the Cloud Cost Dashboard backend (FastAPI) and frontend (nginx/React).

**This chart does not provision Postgres.** Point `values.postgres.*` at an
existing server, then let the chart's migration Job prepare the database.

## What the migration Job does

`templates/job-db-migrate.yaml` runs as a `pre-install,pre-upgrade` Helm hook,
before the backend/frontend Deployments are created or updated:

1. **`db-init` (init container)** — runs `templates/configmap-db-init.yaml`'s
   `db_init.py` script. It connects to the Postgres maintenance database
   (`values.postgres.admin.database`, default `postgres`) with the admin
   credentials, checks `pg_database` for `values.postgres.database`, and issues
   `CREATE DATABASE` only if it's missing. Safe to run on every install/upgrade.
2. **`migrate` (container)** — runs `alembic upgrade head` using the same
   backend image, applying any schema migrations under `backend/alembic/versions/`
   that haven't been applied yet.

Both steps use the backend image (it already has `psycopg` and `alembic`
installed), so no extra image needs to be built.

The Job is named `<release>-migrate-<revision>` and deletes itself after
succeeding (`helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded`),
so every install/upgrade gets a fresh, inspectable run.

## Install

```sh
helm install dashboard-cloud ./temp \
  --set postgres.host=my-postgres.internal \
  --set postgres.username=cloudcost \
  --set postgres.password=... \
  --set postgres.database=cloudcost \
  --set config.jwtSecret=... \
  --set config.adminPassword=... \
  --set config.secretsEncryptionKey=$(python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())") \
  --set backend.image.repository=your-registry/dashboard-cloud-backend \
  --set backend.image.tag=1.0.0 \
  --set frontend.image.repository=your-registry/dashboard-cloud-frontend \
  --set frontend.image.tag=1.0.0
```

Prefer a private values file over a long `--set` list for real credentials, e.g.
`helm install dashboard-cloud ./temp -f values.secret.yaml` (keep that file out
of git, same as `.env` in the rest of this repo).

If the Postgres user in `postgres.username` doesn't have `CREATEDB`, set
`postgres.admin.username` / `postgres.admin.password` to a user that does (or a
superuser) — the migrate Job uses those only to create the database, while the
app itself keeps using `postgres.username`.

## Upgrade

```sh
helm upgrade dashboard-cloud ./temp -f values.secret.yaml
```

Each upgrade re-runs the migrate Job first, so any new Alembic revision is
applied before the new backend Pods start.

## Structure

```
temp/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── _helpers.tpl              # name/label helpers, DSN builders
│   ├── secret-app.yaml           # DATABASE_URL, JWT_SECRET, etc. (skipped if existingSecret is set)
│   ├── configmap-db-init.yaml    # the db_init.py script
│   ├── job-db-migrate.yaml       # pre-install/pre-upgrade hook Job (db-init + alembic upgrade head)
│   ├── backend-deployment.yaml
│   ├── backend-service.yaml
│   ├── frontend-configmap.yaml   # nginx.conf pointed at this chart's backend Service
│   ├── frontend-deployment.yaml
│   ├── frontend-service.yaml
│   ├── ingress.yaml              # disabled by default
│   └── NOTES.txt
└── README.md
```

## Notes

- Set `frontend.enabled=false` to deploy only the backend + migration Job.
- `existingSecret` lets you manage credentials with something like External
  Secrets/Sealed Secrets instead of `values.config`/`values.postgres` — see the
  key list in `templates/secret-app.yaml`.
