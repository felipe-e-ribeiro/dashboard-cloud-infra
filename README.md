# dashboard-cloud-infra

Infra do "Cloud Cost Dashboard" (AWS + OCI, usuário único — código em
[dashboard-cloud](https://github.com/felipe-e-ribeiro/dashboard-cloud)),
via [`platform-chart`](https://github.com/felipe-e-ribeiro/personal-charts).

Migrado do chart bespoke (Deployment/Service/Ingress/Job de migração
escritos à mão) pro `platform-chart` em 2026-09-13 — ver
`PERSONAL-INFRA-CONTEXT.md` no repo `skill-personalsre` pro histórico
completo da decisão.

## Estrutura

- `Chart.yaml` / `values.yaml`: consome o `platform-chart` como
  dependência — schema completo de cada seção em
  [`platform-chart/README.md`](https://github.com/felipe-e-ribeiro/personal-charts/blob/main/README.md)
  e `values.yaml` daquele repo.
- `resources.yaml`: documenta as chaves esperadas no secret do OCI Vault
  (`dashboard-cloud-app-secrets`) — não consumido automaticamente ainda,
  é referência pra criar/atualizar o secret manualmente.
- `templates/external-secret.yaml`: `ExternalSecret` que materializa o
  secret do Vault como Secret do Kubernetes (`dashboard-cloud-secrets`),
  via `ClusterSecretStore` (`argocd-bootstrap`).
- `templates/ingress-auth.yaml`: **template extra que não existe nos
  outros `<app>-infra`.** O `platform-chart` só roteia um `apiPath`
  ("/api") direto pra api; este app também usa `/auth/*` (login/logout —
  ver `frontend/api/client.ts` no repo do código). Sem esse Ingress
  adicional, `/auth/*` cairia no catch-all `/` e seria servido pelo pod
  do frontend, cujo `nginx.conf` faz `proxy_pass` pra um host `backend`
  que só existe no docker-compose local, não no Kubernetes — login
  quebraria em produção. Descoberto rastreando o `nginx.conf` antes do
  primeiro deploy, não em produção.

## Descoberta no cluster (ArgoCD)

Este app é descoberto automaticamente via
[`argocd-bootstrap/apps-registry/dashboard-cloud.yaml`](https://github.com/felipe-e-ribeiro/argocd-bootstrap)
— sem `Application` escrita à mão. Namespace = `dashboard-cloud`.

## Postgres

Sem StatefulSet próprio — reaproveita a instância já existente do
`comprasweb` (`comprasweb-postgres.comprasweb.svc.cluster.local:5432`),
banco `dashboard_cloud` dedicado dentro dela (mesmo padrão do `pulse`,
banco `pulse` na mesma instância). Criado manualmente uma vez:

```bash
kubectl exec -n comprasweb comprasweb-postgres-0 -- psql -U compras -d postgres \
  -c "CREATE DATABASE dashboard_cloud OWNER compras;"
```

Diferente do `pulse` (que tem um `db_bootstrap.py` que cria o banco
sozinho no startup), este app espera o banco já existir — `alembic
upgrade head` (rodado pelo próprio `CMD` do `Dockerfile` do backend)
só cuida do schema.

## Secret no Vault

Criado/atualizado direto no Vault (não via `repository_dispatch`/Terraform):

```bash
oci vault secret create-base64 --profile DEV \
  --compartment-id <compartment_id> --vault-id <vault_id> --key-id <key_id> \
  --secret-name "dashboard-cloud-app-secrets" \
  --secret-content-content "$(base64 -i secret.json)" \
  --secret-content-stage CURRENT --wait-for-state ACTIVE
```

`secret.json` com as chaves listadas em `resources.yaml`. Depois de
criar/atualizar, força o `ExternalSecret` a resincronizar na hora:

```bash
kubectl annotate externalsecret dashboard-cloud-secrets -n dashboard-cloud \
  force-sync="$(date +%s)" --overwrite
```

## Deploy de uma imagem nova

Ainda não tem automação de CI que bump a tag aqui sozinha (diferente do
`pulse`/`PULSE_INFRA_PAT` e do `compras`/`update-infra` — ver
`PERSONAL-INFRA-CONTEXT.md`, pendência conhecida). Depois que o
`build-and-push` do `dashboard-cloud` publicar a imagem nova no GHCR,
edite `platform-chart.api.image.tag` / `platform-chart.frontend.image.tag`
em `values.yaml` manualmente e dê push — o ArgoCD sincroniza sozinho.

## Validar localmente (sem cluster)

```bash
helm dependency build .
helm template dashboard-cloud . > /dev/null
```
