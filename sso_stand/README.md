# SSO stand — Semaphore UI with OpenLDAP and Dex

A small stand for testing Semaphore's LDAP and OIDC logins on DigitalOcean. It
is independent of [`ha_stand`](../ha_stand): own root module, own `.env`, own
scripts. Both stands build their droplets from the shared modules in
[`../modules/do/`](../modules).

## Topology

| Droplet     | Module                                       | What it runs                                       |
| ----------- | -------------------------------------------- | -------------------------------------------------- |
| `ui-1`      | [`semaphore`](../modules/do/semaphore)       | Semaphore Pro on `:80`, no HA block, local tasks   |
| `postgres`  | [`postgres`](../modules/do/postgres)         | PostgreSQL, VPC only                               |
| `idp`       | [`idp`](../modules/do/idp)                   | OpenLDAP and/or Dex with Docker Compose            |

There is no Redis, load balancer or runner. Semaphore is published as the
proxied `<name>-ui.<parent_domain>` record, Dex as `<name>-dex.<parent_domain>`.
TLS terminates at the Cloudflare edge and the origins speak plain HTTP on `:80`,
so the zone SSL mode must be **Flexible** (525/526 means the zone setting, not
the stand). Port 80 of both droplets is open to Cloudflare's edge ranges only.

## Identity providers

`identity_providers` in the workspace `config.yml` switches the providers; both
default to `true`, at least one must stay on:

```yaml
identity_providers:
  ldap: true    # OpenLDAP + Semaphore's ldap_* settings
  dex: true     # Dex + Semaphore's oidc_providers
```

| Service  | Image                               | Exposure                                       | Semaphore config                                     |
| -------- | ----------------------------------- | ---------------------------------------------- | ---------------------------------------------------- |
| OpenLDAP | `osixia/openldap:1.5.0`             | plain LDAP `:389`, `cluster_ip_range` only     | `ldap_*` (no TLS, bind as `cn=admin`)                |
| Dex      | `ghcr.io/dexidp/dex:v2.45.1-alpine` | `:80` behind proxied `<name>-dex`, edge only   | `oidc_providers.dex` + `oidc_providers.unavailable`  |

LDAP and Dex are two **independent** login methods: Dex has no LDAP connector
and authenticates its own static users. `unavailable` is a deliberately
unreachable OIDC provider (`http://127.0.0.1:1/oidc`) kept from the fixtures for
the provider-failure check. The `idp` module builds these Semaphore settings
itself (`semaphore_config` output), so issuer, client and DNs always match the
droplet.

Directory, users, client and secrets mirror the integration-tests fixtures
(`test-environment/profiles/feature-ldap-tls` and `feature-oidc-local`), so the
tests run against the stand unchanged:

| Provider | Login                       | Password                       | Purpose                                          |
| -------- | --------------------------- | ------------------------------ | ------------------------------------------------ |
| LDAP     | `ldap.user`                 | `Bookwright-LDAP-42!`          | regular directory login                          |
| LDAP     | `ldap.invalid`              | `Bookwright-LDAP-Invalid-42!`  | wrong-password checks                            |
| LDAP     | `ldap-admin-conflict`       | `Bookwright-LDAP-Conflict-42!` | `mail: admin@localhost`, collides with the admin |
| Dex      | `oidc.user@bookwright.test` | `Bookwright-OIDC-42!`          | regular OIDC login                               |
| Dex      | `admin@localhost`           | `Bookwright-OIDC-Conflict-42!` | collides with the admin by email                 |

The LDAP base DN is `dc=bookwright,dc=test`, users live under
`ou=people,dc=bookwright,dc=test`. The two secrets, `ldap_admin_password` and
`dex_client_secret`, default to the fixture values in
[`do/variables.tf`](do/variables.tf) — public test values, not real secrets —
and can be overridden with `TF_VAR_ldap_admin_password` /
`TF_VAR_dex_client_secret`. The Semaphore admin email is always
`admin@localhost`, so the conflict users really collide with the local admin.

**Semaphore version.** Needs **≥ 2.20.16-beta8**; `TF_VAR_semaphore_version` has
no default, `.env.example` sets beta8.

**Replacing `idp`.** Its private IP is part of the Semaphore node's
`user_data` (`ldap_server`), so replacing `idp` or toggling a provider replaces
the node too, with a fresh database bootstrap of the admin user.

## Quick start

```sh
cd sso_stand
cp .env.example .env                              # tokens, passwords, keys
cp -r ../workspaces/example-sso ../workspaces/sso1  # subscription key, VPC range

cd do
./up.sh sso1      # apply, then wait for /api/ping
./down.sh sso1    # destroy everything, Cloudflare records included
```

The workspace name is the stand's prefix for droplet tags, firewalls, the VPC
and DNS records, so it must not clash with an `ha_stand` workspace, and
`cluster_ip_range` must not overlap other VPCs in the region.

Outputs: `semaphore_url`, `semaphore_server`, `postgres_server`, `idp_server`
and `dex_issuer_url` (`https://<name>-dex.<parent_domain>/dex`, the
`provider_url` of `oidc_providers.dex`, `null` with Dex off).

## Checks

```sh
# Dex discovery through Cloudflare — 200 with the issuer https://<name>-dex.<domain>/dex
curl https://<name>-dex.<domain>/dex/.well-known/openid-configuration

# LDAP from the Semaphore node (ldapsearch is not installed there by default)
apt-get install -y ldap-utils
ldapsearch -x -H ldap://<idp private ip>:389 \
  -D 'cn=admin,dc=bookwright,dc=test' -w 'Bookwright-LDAP-Bind-42!' \
  -b 'ou=people,dc=bookwright,dc=test' '(uid=ldap.user)'

# LDAP login through Semaphore — 204
curl -i -X POST https://<name>-ui.<domain>/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"auth":"ldap.user","password":"Bookwright-LDAP-42!","method":"ldap"}'

# Provider failure — 500
curl -i https://<name>-ui.<domain>/api/auth/oidc/unavailable/login
```

Dex login is checked in a browser: the login page of `semaphore_url` shows a
"Bookwright Dex" button that redirects to Dex; sign in as
`oidc.user@bookwright.test` / `Bookwright-OIDC-42!` and Dex returns you to
Semaphore logged in (`skipApprovalScreen` is on).

**Known defect, not a stand bug.** LDAP login as `ldap-admin-conflict` answers
`500` instead of the expected `401` (successful bind, then a unique-constraint
failure on the email). It is tracked in the integration tests'
`test-environment/known-defects.md`.
