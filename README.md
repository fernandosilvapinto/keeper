# Keeper

Serviço de identidade partilhado pelas aplicações Pistachio, CARGA e futuras.
Keycloak em modo de desenvolvimento, com base de dados própria.

## Serviços

| Serviço | Porta | Papel | Perfil |
|---|---|---|---|
| `keeper` | 8081 | Identity Provider e Authorization Server | sempre |
| `keeper` (gestão) | 9000 | `/health` e `/metrics` | sempre |
| `keeper-db` | 5433 | PostgreSQL dedicado ao Keycloak | sempre |
| `keeper-ldap` | 1389 | Diretório LDAP para praticar federação | `federation` |
| `keeper-ldapadmin` | 8083 | Interface web do LDAP | `federation` |
| `keeper-openfga` | 8084 / 3001 | Autorização por recurso | `authz` |

Nenhuma destas portas colide com o Pistachio (5000, 5432, 5173, 5174) nem com o
CARGA (8080, 5273, 5432).

## Arranque

```
cd C:\dev\keeper
docker compose up -d
```

Consola: http://keeper.localtest.me:8081/admin — `admin` / `admin`

O domínio `localtest.me` e os seus subdomínios resolvem para 127.0.0.1 por DNS
público. Se a rede local bloquear a resolução, acrescenta ao ficheiro
`C:\Windows\System32\drivers\etc\hosts` a linha `127.0.0.1 keeper.localtest.me`.

## Criar o realm

```
./bootstrap-realm.sh
```

A partir do Git Bash ou do WSL. Cria o realm `keeper` com os clients das três
aplicações, as permissões, os papéis e quatro utilizadores de demonstração.

## Verificar

```
curl -s http://keeper.localtest.me:8081/realms/keeper/.well-known/openid-configuration
```

## Dependência externa

O Keeper envia email através do serviço de mensagens em `C:\dev\mail-service`,
alcançado por `host.docker.internal:1025`. Trata-se de um fornecedor externo ao
Keeper: não partilham rede Docker nem ciclo de vida.

## Perfis opcionais

```
docker compose --profile federation up -d
docker compose --profile authz up -d
```

## Origens registadas no realm

| Client | Origem |
|---|---|
| `pistachio-admin` | http://localhost:5173 |
| `pistachio-client` | http://localhost:5174 |
| `carga-web` | http://localhost:5273 |
