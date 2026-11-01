# SSO stand — Semaphore UI with two OpenLDAPs, Dex and Keycloak

A small stand for testing Semaphore's LDAP and OIDC logins on DigitalOcean. It
is independent of [`ha_stand`](../ha_stand): own root module, own `.env`, own
scripts. Both stands build their droplets from the shared modules in
[`../modules/do/`](../modules).

## Topology

| Droplet     | Module                                       | What it runs                                       |
| ----------- | -------------------------------------------- | -------------------------------------------------- |
| `ui-1`      | [`semaphore`](../modules/do/semaphore)       | Semaphore Pro on `:80`, no HA block, local tasks   |
| `postgres`  | [`postgres`](../modules/do/postgres)         | PostgreSQL, VPC only                               |
| `idp`       | [`idp`](../modules/do/idp)                   | 2x OpenLDAP, Dex, Keycloak with Docker Compose     |

There is no Redis, load balancer or runner. Semaphore is published as the
proxied `<name>-ui.<parent_domain>` record, Dex as `<name>-dex.<parent_domain>`,
Keycloak as `<name>-kc.<parent_domain>`. TLS terminates at the Cloudflare edge
and the origins speak plain HTTP on `:80`, so the zone SSL mode must be
**Flexible** (525/526 means the zone setting, not the stand). Port 80 of both
droplets is open to Cloudflare's edge ranges only; on `idp` it is served by
Caddy, which routes to Dex or Keycloak by hostname.

## Identity providers

`identity_providers` in the workspace `config.yml` switches the providers; all
default to `true`, at least one must stay on:

```yaml
identity_providers:
  ldap: true      # OpenLDAP dc=bookwright + Semaphore's ldap_providers.bookwright
  ldap2: true     # OpenLDAP dc=marlowe    + Semaphore's ldap_providers.marlowe
  dex: true       # Dex + Semaphore's oidc_providers.dex
  keycloak: true  # Keycloak + Semaphore's oidc_providers.keycloak
```

| Service  | Image                               | Exposure                                       | Semaphore config                                     |
| -------- | ----------------------------------- | ---------------------------------------------- | ---------------------------------------------------- |
| OpenLDAP | `osixia/openldap:1.5.0`             | plain LDAP `:389`, `cluster_ip_range` only     | `ldap_providers.bookwright` (no TLS, bind `cn=admin`)|
| OpenLDAP | `osixia/openldap:1.5.0`             | plain LDAP `:390`, `cluster_ip_range` only     | `ldap_providers.marlowe` (no TLS, bind `cn=admin`)   |
| Dex      | `ghcr.io/dexidp/dex:v2.45.1-alpine` | Caddy `:80`, proxied `<name>-dex`, edge only   | `oidc_providers.dex`                                 |
| Keycloak | `quay.io/keycloak/keycloak:26.4`    | Caddy `:80`, proxied `<name>-kc`, edge only    | `oidc_providers.keycloak`                            |

All of them are **independent** login methods for Semaphore. The two
directories are configured through the multi-provider `ldap_providers` map
(keys `bookwright`, `marlowe`), not the legacy flat `ldap_*` keys; they have
different base DNs and disjoint users, so a login against one can never be
answered by the other. Dex has no LDAP connector and authenticates its own
static users. Keycloak
runs in dev mode with its own realm `bookwright` (users, group, client),
imported from a JSON the `idp` module renders at apply time
([`keycloak.tf`](../modules/do/idp/keycloak.tf)). With any OIDC provider on,
`oidc_providers.unavailable` is a deliberately unreachable provider
(`http://127.0.0.1:1/oidc`) kept from the fixtures for the provider-failure
check. The `idp` module builds all these Semaphore settings itself
(`semaphore_config` output), so issuers, clients and DNs always match the
droplet.

The first directory and Dex (users, client, secrets) mirror the
integration-tests fixtures (`test-environment/profiles/feature-ldap-tls` and
`feature-oidc-local`), so the tests run against the stand unchanged; the second
directory and Keycloak have no fixture, their users are stand values:

| Provider | Login                       | Password                       | Groups   | Purpose                                          |
| -------- | --------------------------- | ------------------------------ | -------- | ------------------------------------------------ |
| LDAP     | `ldap.user`                 | `Bookwright-LDAP-42!`          | `devops` | regular directory login                          |
| LDAP     | `ldap.invalid`              | `Bookwright-LDAP-Invalid-42!`  | `devops` | wrong-password checks                            |
| LDAP     | `ldap-admin-conflict`       | `Bookwright-LDAP-Conflict-42!` | `devops` | `mail: admin@localhost`, collides with the admin |
| LDAP 2   | `marlowe.user`              | `Marlowe-LDAP-42!`             | `devops` | regular login against the second directory       |
| LDAP 2   | `marlowe.ops`               | `Marlowe-LDAP-Ops-42!`         | `devops` | second user of the second directory              |
| LDAP 2   | `marlowe-admin-conflict`    | `Marlowe-LDAP-Conflict-42!`    | `devops` | `mail: admin@localhost`, collides with the admin |
| Dex      | `oidc.user@bookwright.test` | `Bookwright-OIDC-42!`          | —        | regular OIDC login                               |
| Dex      | `admin@localhost`           | `Bookwright-OIDC-Conflict-42!` | —        | collides with the admin by email                 |
| Keycloak | `kc.user`                   | `Bookwright-KC-42!`            | `devops` | regular OIDC login with groups                   |
| Keycloak | `kc-admin-conflict`         | `Bookwright-KC-Conflict-42!`   | `devops` | `admin@localhost`, collides with the admin       |

The base DNs are `dc=bookwright,dc=test` (`:389`) and `dc=marlowe,dc=test`
(`:390`); in both, users live under `ou=people,…`, groups under `ou=groups,…`
(`groupOfUniqueNames`; the image's memberof overlay also gives each member a
`memberOf` attribute) and every user is in `cn=devops`. Admin of each
directory is `cn=admin,<base dn>` with `ldap_admin_password` /
`ldap2_admin_password`.

**Groups in Keycloak.** Keycloak has real groups: the realm has a group
`devops` with every user in it, and the `semaphore` client carries a *Group
Membership* protocol mapper that puts the group names (without the leading
`/`) into the `groups` claim of the id, access and userinfo tokens. The mapper
sits on the client, so the default scopes already deliver the claim and
`oidc_providers.keycloak` needs no `scopes` override. More groups/users: edit
`keycloak_groups` / `keycloak_users` in `keycloak.tf` (replaces the droplet) or
use the admin console `keycloak_admin_url` (`admin` /
`TF_VAR_keycloak_admin_password`, default `Bookwright-KC-Admin-42!`).

**Groups in Dex.** Dex has no groups for static users (`staticPasswords` has
no such field; groups only ever come from connectors), so the Dex entries above
carry none. Keycloak is the OIDC provider to use for group checks.

The secrets `ldap_admin_password`, `ldap2_admin_password`, `dex_client_secret`,
`keycloak_client_secret` and `keycloak_admin_password` default to public test
values in [`do/variables.tf`](do/variables.tf) — not real secrets — and can be
overridden with the matching `TF_VAR_*`. The Semaphore admin email is always
`admin@localhost`, so the conflict users really collide with the local admin.

**Semaphore version.** Needs **≥ 2.20.16-beta8**; `TF_VAR_semaphore_version` has
no default, `.env.example` sets beta8.

**Replacing `idp`.** Its private IP is part of the Semaphore node's
`user_data` (the LDAP `server` addresses), so replacing `idp` or toggling a provider replaces
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

Outputs: `semaphore_url`, `semaphore_server`, `postgres_server`, `idp_server`,
`dex_issuer_url` (`https://<name>-dex.<parent_domain>/dex`, the `provider_url`
of `oidc_providers.dex`, `null` with Dex off), `keycloak_issuer_url`
(`https://<name>-kc.<parent_domain>/realms/bookwright`) and
`keycloak_admin_url`.

Keycloak in dev mode takes a couple of minutes to start on the `s-1vcpu-2gb`
droplet; `docker compose up --wait` in cloud-init blocks until its health check
passes, so `up.sh` may finish before `<name>-kc` answers.

## Checks

```sh
# Dex discovery through Cloudflare — 200 with the issuer https://<name>-dex.<domain>/dex
curl https://<name>-dex.<domain>/dex/.well-known/openid-configuration

# Keycloak discovery — 200 with the issuer https://<name>-kc.<domain>/realms/bookwright
curl https://<name>-kc.<domain>/realms/bookwright/.well-known/openid-configuration

# LDAP from the Semaphore node (ldapsearch is not installed there by default)
apt-get install -y ldap-utils
ldapsearch -x -H ldap://<idp private ip>:389 \
  -D 'cn=admin,dc=bookwright,dc=test' -w 'Bookwright-LDAP-Bind-42!' \
  -b 'ou=people,dc=bookwright,dc=test' '(uid=ldap.user)'

# the group and its members / memberOf on a user
ldapsearch -x -H ldap://<idp private ip>:389 \
  -D 'cn=admin,dc=bookwright,dc=test' -w 'Bookwright-LDAP-Bind-42!' \
  -b 'ou=groups,dc=bookwright,dc=test' '(cn=devops)'
ldapsearch -x -H ldap://<idp private ip>:389 \
  -D 'cn=admin,dc=bookwright,dc=test' -w 'Bookwright-LDAP-Bind-42!' \
  -b 'ou=people,dc=bookwright,dc=test' '(uid=ldap.user)' memberOf

# second directory
ldapsearch -x -H ldap://<idp private ip>:390 \
  -D 'cn=admin,dc=marlowe,dc=test' -w 'Marlowe-LDAP-Bind-42!' \
  -b 'ou=people,dc=marlowe,dc=test' '(uid=marlowe.user)'

# LDAP login through Semaphore — 204. With ldap_providers the method names the
# provider id; check the exact value against the Semaphore build under test
# (the legacy flat config used "method":"ldap").
curl -i -X POST https://<name>-ui.<domain>/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"auth":"ldap.user","password":"Bookwright-LDAP-42!","method":"bookwright"}'
curl -i -X POST https://<name>-ui.<domain>/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"auth":"marlowe.user","password":"Marlowe-LDAP-42!","method":"marlowe"}'

# Provider failure — 500
curl -i https://<name>-ui.<domain>/api/auth/oidc/unavailable/login
```

Dex login is checked in a browser: the login page of `semaphore_url` shows a
"Bookwright Dex" button that redirects to Dex; sign in as
`oidc.user@bookwright.test` / `Bookwright-OIDC-42!` and Dex returns you to
Semaphore logged in (`skipApprovalScreen` is on).

Keycloak login likewise: the "Bookwright Keycloak" button, then `kc.user` /
`Bookwright-KC-42!` on the Keycloak page. To see the claim without Semaphore,
look at a token in the admin console (*Clients → semaphore → Client scopes →
Evaluate*, user `kc.user`, *Generated ID token*) — it has
`"groups": ["devops"]`.

**Known defect, not a stand bug.** LDAP login as `ldap-admin-conflict` answers
`500` instead of the expected `401` (successful bind, then a unique-constraint
failure on the email). It is tracked in the integration tests'
`test-environment/known-defects.md`.
