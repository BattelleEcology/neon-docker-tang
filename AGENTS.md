# AGENTS.md

Guidance for coding agents working in this repository.

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

- **Builder stage** compiles `jose` and then `tang` from source with meson/ninja into `/usr/local`. Versions are pinned via `JOSE_COMMIT_SHA` / `TANG_COMMIT_SHA` build args (currently git tags, despite the names). The `# renovate:` comment above each `ARG` is what lets Renovate update it; keep it directly above the `ARG` line.
- **Runtime stage** copies only the built artifacts by explicit path: the `jose` binary, the `libjose.so.0*` shared libs, and `tangd` / `tangd-keygen` (moved from `libexec` to `bin` so they're on `PATH`). If a jose/tang upgrade changes the soname or install layout, these `COPY` lines must be updated to match, and any new runtime library deps added to the runtime `apk add`.
- `tangd` speaks HTTP over stdin/stdout (inetd-style), so `socat` listens on 8080 and forks `tangd /db` per connection. `/db` is not declared as a `VOLUME`; it must be mounted.
- The Alpine version appears in **both** `FROM` lines. Keep them in sync when editing by hand.

## CI and publishing

`.github/workflows/docker-publish.yml` calls the reusable `docker/github-builder` workflow to build `linux/amd64` and `linux/arm64`. Pull requests build only; pushes to `main` and `v*` tags push to Google Artifact Registry using GCP Workload Identity Federation, with all registry/project details coming from `SHARED_WIF_*` repository/org variables.

Releases are automatic; nobody tags by hand. A `plan` job reads the version from the Dockerfile (alpine from the `FROM` lines, jose/tang from their `ARG`s) and fails if any is missing or ambiguous. Builds on `main` tag the image `v<alpine>-tang<tang>-jose<jose>` (e.g. `v3.24.3-tangv15-josev15`), and a `tag` job then tags the repo with the same name if that tag doesn't exist yet. The `v` prefix is required, or the shared Artifact Registry's cleanup rules delete the image. `GITHUB_TOKEN` can't tag a commit that changes `.github/workflows/`, so keep version bumps out of PRs that change workflows.

Renovate (`.github/renovate.json5`) opens one grouped PR for the Docker dependencies (the Alpine base image, plus the jose/tang tags via a regex custom manager) and one for GitHub Actions. Both automerge once the PR build passes. `platformAutomerge` is off because the org ruleset requires no status checks, so GitHub's native auto-merge would merge before the build finishes. Older history is mostly Dependabot bumps from before the switch.
