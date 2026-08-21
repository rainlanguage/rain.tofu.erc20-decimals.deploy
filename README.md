# rain.tofu.erc20-decimals.deploy

The **deployment** half of `rain.tofu.erc20-decimals`: the concrete
`TOFUTokenDecimals` singleton, the rolling `src/generated/candidate/` snapshot
of its deterministic-deploy record (address, codehash, creation and runtime
bytecode), the alias lib `LibTOFUTokenDecimalsDeploy` over those pins, the
frozen per-release snapshots under `src/generated/<tag>/`, and the deploy
script.

The **library** half — the `ITOFUTokenDecimals` interface,
`LibTOFUTokenDecimalsImplementation` which carries the whole of the TOFU logic,
and `LibTOFUTokenDecimals`, the caller-side view of the singleton — lives in
[`rain.tofu.erc20-decimals`](https://github.com/rainlanguage/rain.tofu.erc20-decimals)
and is imported here as the `rain-tofu-erc20-decimals` Soldeer package. The
concrete `TOFUTokenDecimals` is one delegation per entry point into that
implementation library and adds no behaviour of its own.

Consumers that need only the interface or the libraries depend on
`rain-tofu-erc20-decimals`; consumers deploying the singleton, or pinning this
repo's generated record, depend on `rain-tofu-erc20-decimals-deploy`.

## The cross-repo tie

`LibTOFUTokenDecimals` in the library half hardcodes the singleton's address,
codehash and creation code, because a caller of the singleton needs them and
must not need a deploy repo to get them. Nothing in the library half can check
those constants — it has no concrete to check them against. So the assertions
tying them to real compiler output live here, in
`test/src/lib/LibTOFUTokenDecimals.t.sol`, where
`type(TOFUTokenDecimals).creationCode` exists.

That is also why the four caller-lib happy-path suites moved here with the
concrete: `LibTOFUTokenDecimals.ensureDeployed()` pins the codehash, so only the
real singleton bytecode can sit at the pinned address and no test scaffold can
stand in for it.

## Releases

This is a deploy repo: releases are **manual `sol-v*` tags**, not merges.

The on-chain deploy is a separate, human-dispatched step, run **before**
tagging: the `Manual sol artifacts` workflow runs `script/Deploy.sol` for the
`tofu-token-decimals` suite. Tagging then runs `rainix-tag-release`, which never
broadcasts a deploy itself; its mechanics live in rainix.

Explorer verification is its own human-dispatched workflow, `Manual sol verify`.
`Manual sol artifacts` submits source only for what its own run broadcast, and
the Zoltu deploy is idempotent, so once the singleton has code on a network that
run broadcasts nothing there and verifies nothing there — re-dispatching it
cannot repair a deploy that landed and then failed verification.
`Manual sol verify` submits for the address that already has code, on every
supported network, and is safe to re-run.

Nothing publishes on merge: a release bumps `[external.package].version` and
freezes the current `src/generated/candidate/` snapshot into a new
`src/generated/<tag>/` in lockstep.

See rainlanguage/rain.tofu.erc20-decimals#29 for the split rationale.
