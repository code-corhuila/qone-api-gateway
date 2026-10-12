# qone-api-gateway

> API gateway: the only entry of the platform

Part of the **Qampus (Quorum One)** distributed system — team `quorum-one`, Grupo 1.
Governance and documentation live in [`qone-docs`](https://github.com/code-corhuila/qone-docs).

## Purpose

The single entry of Qampus (course norm 5.6, Annex F): NGINX, declarative configuration, no
code (ADR-007). It routes `/api/v1/<domain>/...` to each service and `/api/v1/sagas` to the
workflow, rejects a protected route that arrives without `Authorization`, limits rate, handles
CORS and correlation, and answers its own errors with the common envelope. It validates nothing
else: every service validates the token itself (norm 5.3.7). It is the only piece that publishes
a port to the host (norm 5.6.1).

Piece page: `09-microservices/services/01-api-gateway/README.md`. Story: `code-corhuila/qone-docs#48` (HU-PLT-001).

## Layout

```
nginx/
├── nginx.conf                       global: JSON access log with correlationId, limits, includes
├── conf.d/00-resolver.conf          DNS per request (resolver 127.0.0.11, variable in proxy_pass)
├── templates/10-security.conf.template   rate-limit zone, CORS map from GATEWAY_CORS_ORIGINS, correlation, credential filter
├── conf.d/20-server.conf            the server: its own errors with the envelope, the routes
├── snippets/headers.conf            the headers every response carries
├── snippets/{preflight,protected,proxy}.conf   what every location repeats
└── routes/<domain>.conf             one file per domain, plus workflow.conf and _health.conf
tests/smoke.sh                       the checks of Annex F
deploy/                              image and the compose fragment qone-infra includes
```

## Routing table

| Route | Service | Public |
|---|---|---|
| `GET /health` | the gateway itself | yes |
| `/api/v1/identity/*` | `qone-identity-api:8000` | `health`, `auth/register`, `auth/login` |
| `/api/v1/catalog/*` | `qone-catalog-api:8000` | `health` |
| `/api/v1/enrollment/*` | `qone-enrollment-api:8000` | `health`, `certificates/verify/{code}` |
| `/api/v1/billing/*` | `qone-billing-api:8000` | `health` |
| `/api/v1/advisor/*` | `qone-advisor-api:8000` | `health` |
| `/api/v1/sagas*` | `qone-workflow:8000` | no |

Everything else is `404` with the envelope. A protected route without `Authorization` is `401`.
More than 20 requests per second per client (burst 40) is `429` with `Retry-After`. A domain
whose service is down answers `503` on its routes while the rest keep working: names are
resolved per request, never at boot.

## CORS

Only the origins of the front (`GATEWAY_CORS_ORIGINS`, a regular expression; several with `|`).
`Authorization`, `Content-Type`, `Idempotency-Key` and `X-Correlation-Id` are allowed;
`X-Correlation-Id` and `Location` are exposed. An unknown origin receives no
`Access-Control-Allow-Origin`; never `*` with credentials.

## How to run it

```bash
docker build -f deploy/Dockerfile -t qone-api-gateway:dev .
docker network create platform              # once; qone-infra creates it in the full platform
docker run -d --rm --name gateway --network platform -p 8080:8080 -e GATEWAY_CORS_ORIGINS='http://localhost:5173' qone-api-gateway:dev
sh tests/smoke.sh http://localhost:8080      # health, 404, 401, correlation, CORS, 503, 429
```

`ci.yml` does the same on every pull request: build, `nginx -t` on the rendered configuration,
the smoke checks against the container on an isolated network.

## Adding a domain

1. Create `nginx/routes/<domain>.conf` with a variable in `proxy_pass` (`set $upstream http://<service>:8000;` plus `snippets/proxy.conf`).
2. Include `snippets/headers.conf` in every location, `snippets/preflight.conf` for CORS and `snippets/protected.conf` unless the route is public.
3. Run `tests/smoke.sh`.

## Branching

Three permanent branches. **None of them accepts a direct commit** — you enter through a child
branch and leave through a Pull Request.

```
develop  <--PR--  feat/... fix/... chore/...
qa       <--PR--  qa/...
main     <--PR--  release/...  hotfix/...
```

Promotion happens **by re-application** (`git cherry-pick -x`), never by merging one permanent
branch into another: `merge develop -> qa` and `merge qa -> main` do not exist in this model.

`main` requires **1 approval from `ariel5253`**. On `develop` and `qa` the team sets its own review
rule.

Full policy: `00-governance/branching-policy.md` in `qone-docs`.
