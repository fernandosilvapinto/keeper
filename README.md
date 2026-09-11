# Keeper

Self-hosted identity provider built on Keycloak — OpenID Connect, SSO and
role-based authorization across multiple applications.

## Overview

Keeper authenticates people once and issues tokens that every application
accepts, so applications no longer store credentials, sign their own tokens, or
implement login flows. One sign-in serves them all.

It is deliberately application-agnostic. Applications register as OIDC clients
and APIs register as resource servers; the identity provider holds no
application logic and no domain data. Adding an application is a client
registration, not a change to this repository.

| Concept | Role |
|---|---|
| Realm | Security boundary — users, signing keys, clients, sessions |
| Client (public) | Browser or mobile application, Authorization Code with PKCE |
| Client (confidential) | Server-side application, may use Client Credentials |
| Resource server | API that validates tokens; owns its permissions as client roles |
| Client scope | Bundle of protocol mappers, including the audience mapper per API |

## Services

| Service | Port | Role | Profile |
|---|---|---|---|
| `keeper` | 8081 | Identity provider and authorization server | default |
| `keeper` (management) | 9000 | `/health` and `/metrics` | default |
| `keeper-db` | 5433 | Dedicated PostgreSQL instance | default |
| `keeper-ldap` | 1389 | LDAP directory for user federation | `federation` |
| `keeper-ldapadmin` | 8083 | LDAP web interface | `federation` |
| `keeper-openfga` | 8084 / 3001 | Relationship-based authorization engine | `authz` |

The management port is separate from the HTTP port by design and is not meant
to be exposed alongside it.

## Requirements

- Docker with Compose v2
- An SMTP endpoint reachable at `host.docker.internal:1025` for account
  verification and password reset messages. Any SMTP sink works; the identity
  provider treats mail delivery as an external dependency and does not ship one.

## Getting started

Copy `.env.example` to `.env`, then:

```
docker compose up -d
```

Administration console: http://keeper.localtest.me:8081/admin

`localtest.me` and its subdomains resolve to 127.0.0.1 over public DNS. If the
local network blocks that resolution, add `127.0.0.1 keeper.localtest.me` to the
system hosts file.

Optional profiles:

```
docker compose --profile federation up -d
docker compose --profile authz up -d
```

## Scripts

Five scripts, split by responsibility. The first builds the provider; the rest
are parameterized operations that any application can call. None of them
contains application-specific data.

```
./bootstrap-realm.sh
./register-api.sh             <api-id> <permission,permission,...>
./register-spa.sh             <client-id> <origin> <api-id,api-id,...>
./register-role.sh            <role> <api-id>:<permission>,...
./register-service-client.sh  <client-id> <realm-management-role,...> [secret]
```

`bootstrap-realm.sh` creates the realm once: sign-in policy, token and session
lifetimes, brute force protection, the mail provider, and event auditing.

`register-api.sh` creates a resource server, declares its permissions as client
roles, and creates the client scope whose audience mapper puts the API into the
`aud` claim.

`register-spa.sh` registers a browser application as a public client with PKCE
enforced, sets its redirect URIs and web origin, and attaches the audiences it
needs.

`register-role.sh` creates a business role as a composite of permissions drawn
from one or more resource servers.

`register-service-client.sh` creates a confidential client with a service
account, for an application that needs to act on the realm without a user —
creating an account on a visitor's behalf, for instance. Grant it the narrowest
set of realm management roles the task needs, and keep its secret out of source
control.

The registration scripts are idempotent. `register-spa.sh` refuses to register an
application against an API that does not exist, so no client is left without an
audience.

Applications keep their own registration definition in their own repository and
call these scripts. This repository never learns their names.

Verify the realm is serving metadata:

```
curl -s http://keeper.localtest.me:8081/realms/keeper/.well-known/openid-configuration
```

## Documentation

[`docs/onboarding.md`](docs/onboarding.md) covers how an application starts using
this provider and who is responsible for each step — the integration request, who
owns the permission catalog, who approves access, secret rotation, access
certification and decommissioning. It also states the service contract in both
directions: what the provider commits to, and what it requires of every
integrating application.

## Configuration as code

Realm configuration lives in the database, not in this repository. Export it
after any change so that the identity configuration is versioned and reviewable:

```
docker exec keeper /opt/keycloak/bin/kc.sh export --dir /tmp/export --realm keeper
docker cp keeper:/tmp/export/keeper-realm.json ./realms/
```

## Authorization model

Permissions are declared as client roles on each resource server, in
`resource:action` form. Business roles are composite realm roles that aggregate
those permissions. APIs authorize against permissions, never against business
roles, so a new role can be introduced without touching application code.

Resource ownership — whether a subject may act on a specific record — is domain
logic and stays in the application. The identity provider answers who the
subject is and what class of operation they may perform, nothing more.

## Environment

| Variable | Purpose |
|---|---|
| `KC_ADMIN_USER` | Bootstrap administrator, created on first start only |
| `KC_ADMIN_PASSWORD` | Bootstrap administrator password |
| `KC_DB_PASSWORD` | Password for the dedicated PostgreSQL instance |
| `LDAP_ADMIN_PASSWORD` | LDAP administrator password, `federation` profile only |

## Used by

| Application | Registers |
|---|---|
| [pistachio-api](https://github.com/fernandosilvapinto/pistachio-api) | A resource server, two browser clients and a service account |
| [CARGA](https://github.com/fernandosilvapinto/CARGA) | A resource server and one browser client |

Each keeps its own registration definition in its own repository and calls the
scripts above. The link is documentation: nothing in this repository refers to
them.

## Status

This configuration targets local development. It runs Keycloak in `start-dev`
mode over plain HTTP, with a relaxed hostname policy and no clustering. A
production deployment requires `start --optimized`, TLS termination, a fixed
hostname, external key management, and pinned image digests.
