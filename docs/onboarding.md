# Application onboarding

How an application starts using this identity provider, and who is responsible
for each step.

## Principle

The identity service is the custodian of the mechanism, not the owner of the
access. It is responsible for *how* authentication and authorization work. Who
may do what is always a business decision.

When the identity team starts deciding who gets access, two things go wrong: it
becomes a bottleneck for the whole organization, and it carries a risk that does
not belong to it. In an audit, "who approved this access?" cannot be answered
with "the identity team, because someone asked".

## Participants

| Participant | Owns |
|---|---|
| Business owner | Which roles exist and who holds them; approval of every access |
| Application team | The client, the permission catalog, the integration |
| Identity team | The provider, the conventions, the mechanism, the service contract |
| Security and compliance | Policy, reviews, audit |
| Operations | Availability, monitoring, incident response |

In a small organization one person holds several of these. That is legitimate.
What is not legitimate is for a role to have no holder at all, because then
nobody answers for decommissioning or for access certification.

## Stages

| Stage | Proposes | Decides | Executes |
|---|---|---|---|
| Integration request | Application team | Identity (qualifies) | Application team |
| Client type and allowed flows | Identity | Identity | Identity |
| Permission catalog | Application team | Identity reviews conventions | Application team |
| Business roles | Business owner | Business owner | Application team declares |
| Registration in the provider | Application team (pull request) | Identity approves | Pipeline |
| Integration in code | Application team | Application team | Application team |
| Access assignment | Requester's manager | Business owner | Identity or governance tooling |
| Authorization testing | Application team | Security | Application team |
| Production release | Application team | Change management | Both |
| Secret rotation | Identity sets the deadline | Identity | Application team |
| Access certification | Identity triggers | Business owner | Identity or governance tooling |
| Decommissioning | Business owner | Identity | Identity |

## The integration request

A complete request states: the business owner and the technical owner by name;
the application type; the environments; redirect URIs and web origins per
environment; which APIs it will consume; which user data it needs; which
population it authenticates — internal, external or both; the classification of
the data it handles; and its session and multi-factor requirements.

Qualification produces one decision that is never delegated: the client type and
the flows it may use. A browser application is a public client with PKCE
enforced. Requests for the resource owner password flow are refused, because the
application would see the user's password.

## Where responsibility is most often misplaced

**Permissions belong to the application team.** Only they know which operations
exist in their domain. The identity team imposes the conventions — the
`resource:action` format, minimum granularity, least privilege, and a ban on
catch-all permissions that describe nothing.

**Roles belong to the business owner.** Whether a supervisor may approve is a
business decision. The developer declares it; the business owner signs it.

**Assigning access to a person is never the identity team's decision.** It
arrives as a request, approved by the business owner. The identity team executes
and records. The leaver half of that process is the one that fails most often:
people change function and accumulate the access of the old one alongside the
new.

## Decommissioning

A named owner for decommissioning is agreed on the first day, not when the
application is switched off. An abandoned client keeps a valid secret and
redirect URIs pointing at a domain that may later expire and be registered by
someone else. That is a real attack path, and it is the direct consequence of
nobody owning the end of the lifecycle.

## Service contract

What this identity provider commits to:

- Published availability and maintenance windows
- A stated latency budget for the token endpoint
- Advance notice of any change that breaks integrations
- Signing key rotation without interruption, published through JWKS
- Separate environments with configuration parity
- A stated turnaround for registration requests

What it requires of every integrating application:

- Validate `aud` and `iss` on every API
- No deprecated flows: no implicit, no resource owner password
- Respect token lifetimes; never cache a token beyond its expiry
- Fetch signing keys from JWKS; never copy them into configuration
- Provide a back-channel logout endpoint where the application has a server
- Never store tokens where a cross-site scripting flaw can read them

## Boundary

Access request with approval, periodic certification and removal on departure
are identity governance, not authentication. This provider issues and validates
tokens; it does not run approval workflows. That boundary is where a governance
product begins.
