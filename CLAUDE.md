# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Docker image for the [tang](https://github.com/latchset/tang) network-bound disk encryption key server. The whole project is the `Dockerfile` plus a CI workflow; there is no application code and no test suite.

## Build and run locally

```sh
docker build -t tang .

# tangd serves keys from /db; generate a key set into a volume first
docker run --rm -v tang-db:/db tang tangd-keygen /db
docker run --rm -d -p 8080:8080 -v tang-db:/db tang

# smoke test: the advertisement endpoint should return a signed JWS
curl http://localhost:8080/adv
```

## Dockerfile structure

- **Builder stage** compiles `jose` and then `tang` from source with meson/ninja into `/usr/local`. Versions are pinned via `JOSE_COMMIT_SHA` / `TANG_COMMIT_SHA` build args (currently git tags, despite the names).
- **Runtime stage** copies only the built artifacts by explicit path: the `jose` binary, the `libjose.so.0*` shared libs, and `tangd` / `tangd-keygen` (moved from `libexec` to `bin` so they're on `PATH`). If a jose/tang upgrade changes the soname or install layout, these `COPY` lines must be updated to match, and any new runtime library deps added to the runtime `apk add`.
- `tangd` speaks HTTP over stdin/stdout (inetd-style), so `socat` listens on 8080 and forks `tangd /db` per connection. `/db` is not declared as a `VOLUME`; it must be mounted.
- The Alpine version appears in **both** `FROM` lines because Dependabot can't update a build-arg in `FROM`. Keep them in sync when editing by hand.

## CI and publishing

`.github/workflows/docker-publish-multiarch.yml` calls the reusable `docker/github-builder` workflow to build `linux/amd64` and `linux/arm64`. Pull requests build only; pushes to `main` and `v*.*.*` tags push to Google Artifact Registry using GCP Workload Identity Federation, with all registry/project details coming from `SHARED_WIF_*` repository/org variables.

Dependabot (`.github/dependabot.yml`) opens daily PRs for the Alpine base image and GitHub Actions; most commit history is these bumps.
