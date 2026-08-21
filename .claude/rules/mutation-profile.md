---
paths:
  - "src/**"
  - "test/**"
  - "foundry.toml"
---

# Mutation and coverage campaigns run under `FOUNDRY_PROFILE=mutation`

```bash
nix develop -c bash -c 'FOUNDRY_PROFILE=mutation forge test'
```

Three test contracts tie compiler output to a pin rather than to behaviour:

- `LibTOFUTokenDecimalsDeployCandidateTest`
  (`test/src/lib/LibTOFUTokenDecimalsDeployCandidate.t.sol`) asserts the
  generated candidate snapshot equals `type(TOFUTokenDecimals).creationCode`.
- `TOFUTokenDecimalsDeploySnapshotTest`
  (`test/src/abstract/TOFUTokenDecimalsDeploySnapshot.t.sol`) inherits the
  snapshot-versus-source and internal-consistency walks over the same record.
- `LibTOFUTokenDecimalsTest` (`test/src/lib/LibTOFUTokenDecimals.t.sol`) asserts
  that creation code and codehash equal the constants the library half ships.

Those compiler outputs change for any edit to any source file reachable from
`TOFUTokenDecimals`, so all three fail under every source mutation, whether or
not the mutated behaviour is observable. A campaign run on the default profile
scores every mutant `KILLED` and measures nothing.

`[profile.mutation]` in `foundry.toml` sets `no_match_contract` to those three
and inherits everything else from `default`. The default profile keeps the pins,
so CI and releases still catch snapshot drift.
