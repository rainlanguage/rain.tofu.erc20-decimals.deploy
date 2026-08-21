# CLAUDE.md

Only what a capable agent would get _wrong_ from this repo alone. Layout, dev
shells, build/test commands, dependency lists, and which command CI runs are all
discoverable and deliberately absent (rainlanguage/rainix#298).

## What this repo is

The **deploy half** of `rain.tofu.erc20-decimals`: the concrete
`TOFUTokenDecimals` (one delegation per entry point into
`LibTOFUTokenDecimalsImplementation`) plus its deploy pins. The interface and
both libraries are **NOT here** — they arrive as the `rain-tofu-erc20-decimals`
Soldeer dependency (`dependencies/rain-tofu-erc20-decimals-<version>/src/`).

## The cross-repo tie an agent would break

`LibTOFUTokenDecimals` (library half) hardcodes the singleton address, codehash
and creation code. It cannot check them — no concrete there. The assertions that
do live HERE, in `test/src/lib/LibTOFUTokenDecimals.t.sol`. Do not move them
back, and do not "fix" a mismatch by editing either side's constants: a mismatch
means the creation code moved, which breaks every already-deployed singleton and
is not recoverable by redeploying.

## Conventions an agent would get wrong

- Optimizer **1,000,000 runs** — tofu's value. The sibling deploy repos use
  100,000; copying them here moves the address.
- No CBOR metadata (`cbor_metadata = false`, `bytecode_hash = "none"`), solc
  `=0.8.25`, `evm_version = "cancun"`. Deterministic (Zoltu) deploy, so the
  address is a pure function of the bytecode and any of these moves the pins.
- Pragma: concrete contracts, scripts and tests pin `=0.8.25` (exact); library
  and generated files float `^0.8.25` so downstream soldeer consumers on another
  `0.8.x` still compile them.
- All source files need SPDX headers (LicenseRef-DCL-1.0).

## Deploy-pin invariants (the hazards)

- `src/generated/candidate/` is the **rolling** snapshot, rewritten from what
  source compiles to by `script/Build.sol` and currency-checked by CI.
  `LibTOFUTokenDecimalsDeploy.sol` aliases it.
- `src/generated/<tag>/` snapshots are **frozen**: `cutRelease()` freezes the
  candidate into a new tag dir; a release only ADDS one, never edits or deletes
  an existing one. CI enforces append-only.
- `[external.package].version` is the **last released** version. A normal PR
  does not bump it; only a release moves it, in lockstep with a new frozen
  `<tag>/`.
- Generated files (`src/generated/`, `src/lib/`) — do not hand-edit;
  `script/Build.sol` regenerates them.

## Release / deploy shape

- The on-chain deploy is a human-dispatched `Manual sol artifacts` run
  (`workflow_dispatch`), done **before** tagging — never on merge, never part of
  the release workflow, and it is what actually broadcasts.
- A manual `sol-v<version>` tag is the sole release trigger. The release
  mechanics live in rainix's `rainix-tag-release` reusable, not here.
