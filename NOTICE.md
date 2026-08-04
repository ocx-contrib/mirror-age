# NOTICE

This repository packages and redistributes upstream software published by the
[age](https://github.com/FiloSottile/age) project. The Apache-2.0 license in
[`LICENSE`](LICENSE) covers the OCX pipeline files authored here. It does
**not** cover any upstream-derived asset — the redistributed bytes carry their
own license, recorded below.

| Package | GHCR path | Upstream SPDX |
|---|---|---|
| `age` | `ghcr.io/ocx-contrib/age/age` | `BSD-3-Clause` |

---

## `age`

Upstream: <https://github.com/FiloSottile/age>
Published to `ghcr.io/ocx-contrib/age/age`.

| Component | SPDX | Holder |
|---|---|---|
| age (`age`, `age-keygen`, `age-inspect`, `age-plugin-batchpass`) | **BSD-3-Clause** | Copyright (c) 2019 The age Authors |

Verified at the license gate:

```
$ gh api repos/FiloSottile/age/license --jq '{spdx: .license.spdx_id, path: .path}'
{"path":"LICENSE","spdx":"BSD-3-Clause"}
```

BSD-3-Clause is permissive and grants redistribution of the compiled binary
provided the copyright notice, the condition list and the disclaimer are
retained. Every upstream release archive ships its own `LICENSE` file beside
the executables, and that file is republished unmodified inside the OCX bundle
— the retention condition is satisfied by the artifact itself. The canonical
text is <https://github.com/FiloSottile/age/blob/main/LICENSE>. The third
clause forbids using the names of the authors to endorse or promote derived
products; this mirror makes no such claim (see the disclaimer in the index
claim and below).

The published binaries statically link third-party Go modules under permissive
licenses, enumerated in upstream's `go.mod` / `go.sum`.

## Logo

`age/logo.svg` is the **official age logo**, redistributed unaltered from
<https://github.com/FiloSottile/age/tree/main/logo>; `age/logo.png` is a 512px
render of that same file. Upstream's `logo/README.md` states:

> The logos available in this folder are Copyright 2021 Filippo Valsorda.
> Permission is granted to use the logos as long as they are unaltered, are not
> combined with other text or graphic, and are not used to imply your project
> is endorsed by or affiliated with the age project.

It is used here for catalog identification only, unaltered and uncombined. No
endorsement or affiliation is implied — this is an unaffiliated mirror. The
logos were designed by [Studiovagante](https://www.studiovagante.it).

No modifications are made to any upstream artifact in this repository; they are
republished byte-for-byte inside an OCX bundle.
