---
name: build-cfe-from-sources
description: Build a 1C .cfe extension from unpacked sources using a temporary infobase, vrunner init-dev, and vrunner compileexttocfe. Use when the user asks to assemble a .cfe from src, reproduce the tb_cfe_bsp Jenkins flow, or verify extension packaging from sources.
disable-model-invocation: true
---

# Build CFE From Sources

Use this skill to reproduce the Jenkins pattern for building a `.cfe` from unpacked 1C extension sources.

## Source flow

The reference Jenkins flow is:

1. Prepare a temp workspace.
2. Restore a temporary infobase from a `.dt` artifact:
   - `vrunner init-dev --dt <dt> --ibcmd --ibconnection /F<temp-ib> --nocacheuse --v8version <version>`
3. Compile extension sources into `.cfe`:
   - `vrunner compileexttocfe --src <src-dir> --out <out.cfe> --ibcmd --current --build-number <n> --ibconnection /F<temp-ib> --nocacheuse --v8version <version>`
4. Validate the artifact size if a known lower bound exists.

## When to use

Use this when:

- the user asks to build a `.cfe` from `src`
- the repo contains unpacked extension sources and the binary must be regenerated
- you need to mirror the `tb_cfe_bsp` Jenkins pipeline locally

Do not default to `precommit1c --compile` for `.cfe` when the project already uses `vrunner compileexttocfe`.

## Required inputs

- source directory with unpacked extension, for example `src/extensions/DEV_77397` or `src/cfe`
- target `.cfe` path, for example `extensions/DEV_77397.cfe`
- platform version, for example `8.3.27.1936`
- base `.dt` or existing infobase for compilation

## Local workflow

1. Create or clean a temp directory for the infobase.
2. Initialize the infobase from `.dt`:

```bash
vrunner init-dev --dt .temp/base.dt --ibcmd --ibconnection /F.temp/ib --nocacheuse --v8version 8.3.27.1936
```

3. Compile sources to `.cfe`:

```bash
vrunner compileexttocfe --src src/cfe --out bin/output.cfe --ibcmd --current --build-number 7 --ibconnection /F.temp/ib --nocacheuse --v8version 8.3.27.1936
```

4. Verify the output file exists and has a sane size. If Jenkins has a known minimum threshold, reuse it.

## Notes

- `--ibcmd` matches the Jenkins job and avoids Designer-only assumptions.
- `--current` allows build-number/version substitution used by the pipeline.
- For BSP-style build repos, the source directory may be `src/cfe`.
- For task extensions, adapt `--src` and `--out` to the specific extension path.
- If compilation produces a tiny file, treat it as a failed build and inspect the command, source root, and infobase preparation.

## Example from Jenkins

```bash
vrunner init-dev --dt .temp/tb_main_1.2.2044+2798.dt --ibcmd --ibconnection /F.temp/ib --nocacheuse --v8version 8.3.27.1936
vrunner compileexttocfe --src src/cfe --out bin/tb_bsp_$version.cfe --ibcmd --current --build-number 7 --ibconnection /F.temp/ib --nocacheuse --v8version 8.3.27.1936
```
