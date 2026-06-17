# Divyam artifacts versioning contract (FROZEN)

This is the source of truth for how Divyam stack artifacts are **named, versioned, and traced**. The
artifact files here pin every chart version + image tag for one coherent build of the stack. The
nightly→stable **pipeline is not built yet** — this contract is frozen so the pipeline and all
consumers (helmfile, `scripts/k8s.sh`) can be implemented independently.

An "artifacts file" is `chartBasePath` + per-chart `{chart: {version[, subPath]}, values: {image: {tag}}}`
plus a scalar `release:` metadata block (below). The helmfile `unset`s `chartBasePath` and `release`
before merging, so neither reaches charts.

## Channels & layout

```
releases/
  VERSIONING.md            # this contract
  NEXT_VERSION             # one line: target stable semver core for the in-progress cycle (e.g. 1.0.1)
  index.yaml               # append-only ledger: every nightly + each promotion (durable lineage)
  stable/
    latest                 # pointer: one line = a stable version id (e.g. 1.0.0)
    <semver>-artifacts.yaml
  nightly/
    latest                 # pointer: one line = a nightly id
    <base>-nightly.<YYYYMMDD>.<seq>-artifacts.yaml
  <legacy>-artifacts.yaml  # pre-contract flat files (e.g. 26.04.01*) — still resolvable, not migrated
```

## Naming conventions

- **Stable:** strict semver `MAJOR.MINOR.PATCH` (no leading zeros) → `stable/<semver>-artifacts.yaml`.
- **Nightly:** a semver **pre-release** of the next target stable:
  `MAJOR.MINOR.PATCH-nightly.<YYYYMMDD>.<seq>` → `nightly/<id>-artifacts.yaml`.
  - `<YYYYMMDD>` = UTC build date; `<seq>` = monotonic per-day counter (1-based).
  - Semver pre-release ordering guarantees `1.1.0-nightly.* < 1.1.0`; `sort -V` orders nightlies
    chronologically (date then seq) and stables by version.
- **`<channel>/latest`:** a one-line pointer holding an id (no `-artifacts.yaml`, no path).
- **`NEXT_VERSION`:** one line, the target stable semver core for the current cycle.
- All ids / pointer contents are plain tokens `[A-Za-z0-9.-]+` (no `=`, no `/`) so `make k8s -- -a <id>`
  is safe (`make` would otherwise eat `name=value` as a variable).

## Version bump strategy (auto vs manual)

The **target core in `NEXT_VERSION` is the only human lever**:
- **Auto-bump (default):** when a stable `X.Y.Z` is released, the pipeline auto-advances `NEXT_VERSION`
  → `X.Y.(Z+1)` (PATCH). With no human action, the next cycle is a patch release.
- **Manual minor/major jump:** a human edits `NEXT_VERSION` to `X.(Y+1).0` (minor) or `(X+1).0.0`
  (major) — a one-line committed, reviewed change — when the upcoming release warrants it.

The nightly suffix `-nightly.<date>.<seq>` is **always auto**; humans never set it. So:
*core = patch-auto / minor-major-explicit; nightly suffix = always auto.*

## Lineage & traceability (stable ↔ nightly)

Two layers, kept deliberately small:

1. **Scalar `release:` block** in every artifacts file (no lists — the file the helmfile reads stays
   small):
   ```yaml
   release:
     channel: stable|nightly
     version: <this file's id>
     base: <target stable core>        # nightly: the target; stable: == version
     created: <RFC3339 UTC>
     source_sha: <build/source git sha>
     seq: <int>                        # nightly only
     promoted_from: <nightly id>       # stable only — the exact nightly that became this stable
   ```
2. **Append-only ledger `index.yaml`** — the durable, queryable history of every nightly and each
   promotion (survives nightly file pruning). One row per artifact, appended in order; past rows are
   never edited or reordered.

A stable release names the exact nightly it came from via `promoted_from`; its full nightly lineage =
the ledger rows (or `nightly/<base>-nightly.*` files) sharing the same `base`.

## Resolution & consumption (already implemented)

`scripts/k8s.sh` flags → env → `k8s/helmfile.yaml.gotmpl`:
- `-C|--channel <stable|nightly>` → `ARTIFACTS_CHANNEL`; `-a|--artifacts-version <id|latest>` →
  `ARTIFACTS_VERSION`. Precedence: CLI flag > env > `.k8s.conf` > default.
- Helmfile precedence:
  1. `ARTIFACTS_CHANNEL` set → `releases/<channel>/<ver|latest>-artifacts.yaml`
     (`latest` = the `<channel>/latest` pointer, else newest by `sort -V`).
  2. only `ARTIFACTS_VERSION` set → `releases/<v>-artifacts.yaml` (legacy flat) → `stable/<v>` → `nightly/<v>`.
  3. neither → local `<valuesDir>/artifacts.yaml` → `stable/latest` → legacy newest (`sort -V`).

Examples: `make k8s -- install -C stable` (latest stable) · `-C stable -a 1.0.0` · `-C nightly -a latest`.
A consumer can keep its local `artifacts.yaml` as default and opt into a channel via flags
(`--artifacts-channel/--artifacts-version`).

## Pipeline obligations (for the future, not-yet-built pipeline)

- **Nightly run:** read `NEXT_VERSION`=base; id = `<base>-nightly.<UTCdate>.<seq>` (seq monotonic/day);
  write `nightly/<id>-artifacts.yaml` (schema + scalar `release:` with `source_sha`); **append a row to
  `index.yaml`**; on passing gates, atomically (write-temp-then-`mv`) update `nightly/latest`=id.
- **Promotion (nightly → stable):** input nightly id `N`, target stable `S` (= `base` of `N`). Copy
  `nightly/N-artifacts.yaml` → `stable/S-artifacts.yaml` **byte-for-byte** (image tags & chart versions
  unchanged); set `channel: stable` + `promoted_from: N`; **append a stable row to `index.yaml`**;
  update `stable/latest`=S; auto-bump `NEXT_VERSION` = `S` with PATCH+1.
- **Hard rules:** ids are immutable (never edit a published `<id>-artifacts.yaml`); only `latest`,
  `NEXT_VERSION`, and `index.yaml` mutate; plain tokens only; the artifacts schema is fixed
  (`chartBasePath` + per-chart + scalar `release:`); **rollback = repoint `latest` to an older id** (no
  file deletion).

## Who produces these files

Artifacts files (`<channel>/<id>-artifacts.yaml`, the `latest` pointers, `NEXT_VERSION`, `index.yaml`)
are produced by **internal release tooling/pipeline** that resolves the latest published chart versions
+ image tags from the internal registries and commits the result here. This open-source repo only
*consumes* them (via the resolution contract above); it does not carry the generator. The internal
tooling must honor the schema, naming, bump strategy, and lineage rules in this document.

## Genesis note

`stable/1.0.0-artifacts.yaml` is the genesis stable release (no nightly predecessor); its chart
versions + image tags are pinned to the latest published artifacts. The first pipeline-built release
will supersede it through normal promotion.
