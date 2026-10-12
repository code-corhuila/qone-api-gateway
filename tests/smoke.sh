#!/usr/bin/env sh
# The checks of Annex F against a running gateway. Usage: tests/smoke.sh http://localhost:8080
# The 503 check targets a domain whose service is not running (advisor by default).
set -eu
BASE="${1:-http://localhost:8080}"
ORIGIN="${ORIGIN:-http://localhost:5173}"
DOWN_ROUTE="${DOWN_ROUTE:-/api/v1/advisor/conversations}"
fail() { echo "FAIL: $1" >&2; exit 1; }
status() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
header() { name="$1"; shift; curl -s -D - -o /dev/null "$@" | tr -d '\r' | grep -i "^$name:" | head -n1 | cut -d' ' -f2-; }

[ "$(status "$BASE/health")" = "200" ] || fail "/health is not 200"
curl -s "$BASE/health" | grep -q '"service":"qone-api-gateway"' || fail "health does not name the gateway"

[ "$(status "$BASE/nothing-here")" = "404" ] || fail "unknown route is not 404"
curl -s "$BASE/nothing-here" | grep -q '"error":"NOT_FOUND"' || fail "404 has no envelope"

[ "$(status "$BASE/api/v1/billing/invoices/me")" = "401" ] || fail "protected route without credential is not 401"
curl -s "$BASE/api/v1/billing/invoices/me" | grep -q '"error":"UNAUTHORIZED"' || fail "401 has no envelope"
curl -s "$BASE/api/v1/billing/invoices/me" | grep -q '"traceId":"' || fail "401 has no traceId"

[ "$(header X-Correlation-Id -H 'X-Correlation-Id: smoke-corr-1' "$BASE/health")" = "smoke-corr-1" ] || fail "correlation id not kept"
generated=$(header X-Correlation-Id "$BASE/health")
[ -n "$generated" ] || fail "correlation id not generated"
[ "$(curl -s -H 'X-Correlation-Id: smoke-corr-2' "$BASE/nothing-here" | grep -o '"traceId":"[^"]*"')" = '"traceId":"smoke-corr-2"' ] || fail "traceId is not the correlation id"

[ "$(status -X OPTIONS -H "Origin: $ORIGIN" -H 'Access-Control-Request-Method: POST' -H 'Access-Control-Request-Headers: idempotency-key' "$BASE/api/v1/billing/invoices")" = "204" ] || fail "preflight is not 204"
header Access-Control-Allow-Headers -X OPTIONS -H "Origin: $ORIGIN" -H 'Access-Control-Request-Method: POST' "$BASE/api/v1/billing/invoices" | grep -qi 'Idempotency-Key' || fail "preflight does not allow Idempotency-Key"
[ "$(header Access-Control-Allow-Origin -H "Origin: $ORIGIN" "$BASE/health")" = "$ORIGIN" ] || fail "allowed origin not echoed"
header Access-Control-Expose-Headers -H "Origin: $ORIGIN" "$BASE/health" | grep -qi 'X-Correlation-Id' || fail "X-Correlation-Id not exposed"
[ -z "$(header Access-Control-Allow-Origin -H 'Origin: http://evil.example' "$BASE/health")" ] || fail "unknown origin received Access-Control-Allow-Origin"

[ "$(status -H 'Authorization: Bearer x' "$BASE$DOWN_ROUTE")" = "503" ] || fail "a stopped service does not answer 503"
curl -s -H 'Authorization: Bearer x' "$BASE$DOWN_ROUTE" | grep -q '"error":"SERVICE_UNAVAILABLE"' || fail "503 has no envelope"
[ "$(status "$BASE/health")" = "200" ] || fail "the gateway is not healthy while a service is down"

# Above 20 r/s with a burst of 40, the gateway answers 429 with the envelope and Retry-After.
tmp=$(mktemp -d)
for i in $(seq 1 80); do curl -s -D "$tmp/$i.h" -o "$tmp/$i.b" -H 'Authorization: Bearer x' "$BASE$DOWN_ROUTE" & done; wait
limited=$(grep -l " 429 " "$tmp"/*.h | head -n1)
[ -n "$limited" ] || fail "no 429 after the burst"
grep -qi '^retry-after:' "$limited" || fail "429 without Retry-After"
grep -q '"error":"TOO_MANY_REQUESTS"' "${limited%.h}.b" || fail "429 has no envelope"
rm -rf "$tmp"
echo "OK: gateway smoke checks passed against $BASE"
