# Themes

Drop a Keycloak theme folder here and it becomes available to every realm in
this provider. Applications keep their own branding in their own repositories
and copy or link it into this directory; nothing here is tracked by git except
this file.

A theme folder looks like this:

```
<name>/
  login/
    theme.properties
    resources/css/login.css
```

Apply it with:

```
./set-realm-theme.sh <realm> <name>
```

In development the provider runs with theme caching disabled, so edits to CSS
are visible on a page refresh without restarting the container.
