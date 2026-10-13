## User story

code-corhuila/qone-docs#NN

## What changes and why

## How it was tested

- [ ] `ci.yml` green: the image builds, `nginx -t` accepts the configuration, `tests/smoke.sh` passes against the container

## Promotion trail

Only towards `qa` or `main`: the re-applied commits, each with its `(cherry picked from commit <sha>)` line.

## Checklist

- [ ] No secrets, no `.env`
- [ ] No business rule here; no token validated here beyond the presence of the header
- [ ] Every proxied location uses a variable in `proxy_pass` and includes `snippets/headers.conf`
