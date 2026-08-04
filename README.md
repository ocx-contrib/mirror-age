# mirror-age

OCX mirror for [age](https://github.com/FiloSottile/age), a simple, modern and
secure file encryption tool. One repository, one spec directory per package.

| Package | Spec | Publishes to | Announced as | Upstream SPDX |
|---|---|---|---|---|
| [age](https://github.com/FiloSottile/age) | [`age/mirror.yml`](age/mirror.yml) | `ghcr.io/ocx-contrib/age/age` | [`ocx.sh/age/age`](https://index.ocx.sh/age/age) | `BSD-3-Clause` |

Each upstream release is discovered, re-bundled, smoke-tested per
`(version, platform)` and only then pushed with cascade tags, after which the
result is announced into the OCX index.

`FiloSottile` is a personal handle rather than a vendor, so the tool names
itself: the namespace is `age`, not the maintainer.

## Layout

```
mirror-base.yml         repo-wide policy the spec inherits via `extends:`
age/
├── mirror.yml          the spec — never at the repo root
├── metadata.json       bundle interface
├── CATALOG.md          → ocx package describe
├── logo.svg / logo.png describe assets, 512px PNG
└── tests/smoke.star    Starlark smoke test
```

`LICENSE` and `NOTICE.md` are shared at the root. The logo is **not** — it sits
beside the spec, because a repo-root `logo.*` sits in no workflow's `paths:`
filter, so replacing it would publish nothing until some unrelated edit
happened to fire.

⚠️ `extends:` is a **shallow** merge of top-level keys. A spec that restates
`platforms:` to change one runner drops every `containers:` entry with it, and
nothing reds — the legs simply stop existing, and every `os.features` claim
goes back to being asserted rather than verified. `age/mirror.yml` does not
restate `platforms:` at all; the measured matrix lives in `mirror-base.yml`.

## Platforms

Five platform entries: both Linux arches, both macOS arches, and
`windows/amd64`. Every anchored asset pattern was checked against the full
asset list of **every** in-range release (v1.3.0, v1.3.1) and matches exactly
one asset each — a pattern matching zero is *silently skipped* by the pipeline,
not an error, and would ship a missing platform under a green run.

**Both Linux keys are bare**, and that is measured rather than reasoned:

| Key | Asset | Measured |
|---|---|---|
| `linux/amd64` | `age-vX.Y.Z-linux-amd64.tar.gz` | `statically linked`, `INTERP` count **0**, `NEEDED` count **0** → **bare** |
| `linux/arm64` | `age-vX.Y.Z-linux-arm64.tar.gz` | identical → **bare** |

All four binaries were checked on both arches and both in-range releases — 16
artifacts, 16 × `INTERP=0 NEEDED=0`. These are CGO-disabled Go builds, so they
require nothing of the host userland: `+libc.musl` would be a false requirement
hiding the package from every glibc host it runs on, and `+libc.glibc` would
hide it from musl. The `alpine:3.20` container leg **on both arches** is what
turns that universality claim into evidence.

**Every real asset is paired 1:1 with a `*.proof` sigsum signature file.** The
terminating `\.tar\.gz$` / `\.zip$` anchor is the only thing keeping
`age-v1.3.1-linux-amd64.tar.gz.proof` out of the `linux/amd64` set; unanchored,
every platform would resolve two assets and the run would die on an ambiguous
match.

Also published upstream and deliberately **not** carried:

- `age-vX.Y.Z-freebsd-amd64.tar.gz` — FreeBSD. OCX has no `freebsd` OS key, so
  the platform cannot be expressed, and no GitHub-hosted runner could test it.
- `age-vX.Y.Z-linux-arm.tar.gz` — a single unqualified 32-bit `arm` build.
  OCX's architecture set is `amd64` and `arm64` only.
- `age-vX.Y.Z-source.tar.gz` — a source snapshot, not a platform binary.
- `*.proof` — the sigsum sidecars.

There is **no** `windows/arm64` asset on any in-range release, so none is
declared.

## Version floor

`versions.min` is **1.3.0**, and the reason is the archive *contents* rather
than the asset names. v1.2.x ships `age/{LICENSE,age,age-keygen}` — two
binaries — while v1.3.0 added `age-inspect` and `age-plugin-batchpass` for
four. A single hand-listed `binaries` claim cannot be true of both sets, so the
floor is what makes the declared interface uniform across the whole range.

## The binaries claim

Every release archive — `.tar.gz` and `.zip` alike — is a single `age/` wrapper
holding the four executables (mode 0755, `.exe` on Windows) at its **root**,
beside a `LICENSE` file. One `strip_components: 1` therefore serves every
platform, and no per-platform `asset_type` or `metadata` override is needed.

After the strip the bundle's only PATH entry is a bare `${installPath}` — the
executables *are* the content root. `bin_scan` only looks *below* an
`${installPath}/<dir>` entry, so `auto`/`verify` is rejected at spec load with
exit 65 (*the verification would inspect no file and pass green whatever the
archive contains*). `age/mirror.yml` therefore sets `bin_scan: "off"` and
`age/metadata.json` hand-lists all four binaries — the blessed shape for this
layout.

## Editing

| File | Edit | Regenerate after |
|------|------|------------------|
| `mirror-base.yml`, `age/mirror.yml` | hand | yes — see below |
| `age/{metadata.json,CATALOG.md,logo.*}` | hand | — |
| `age/tests/smoke.star` | hand | — |
| `.github/workflows/*.yml` | **generated — never hand-edit** | re-run when a spec changes |

```bash
ocx-mirror package pipeline generate ci --spec age/mirror.yml
```

**Name every spec.** `--spec` *appends* rather than replaces, so a command
naming a subset silently stops rendering the rest while staying green — and the
drift guard reds on a generated workflow the current spec set no longer
produces.

`verify-generated.yml` exits 65 on drift. If a generated workflow is wrong, the
spec or the renderer template is wrong — fix it there and regenerate.

Run `direnv allow` once to put the pinned toolchain on `PATH`, and invoke
`ocx-mirror` directly — never `ocx run -- ocx-mirror`, which pins
`OCX_BINARY_PIN` to the bootstrap `ocx` and false-reds the nested push.

## Required secrets

| Secret | Use |
|--------|-----|
| `OCX_ANNOUNCE_TOKEN` | opens the index pull request from the `ocx-contrib/index` fork |
| `OCX_MIRROR_DISCORD_HOOK` | notify-stage Discord webhook URL |

(Inherited from the `ocx-contrib` org with visibility ALL. GHCR pushes use the
run's own `GITHUB_TOKEN` — no registry secret needed.)

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Upstream assets are out of scope; the
redistribution license is recorded in [`NOTICE.md`](NOTICE.md).
