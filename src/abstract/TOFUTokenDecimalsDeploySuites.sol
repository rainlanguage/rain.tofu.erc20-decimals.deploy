// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {StdConstants} from "forge-std-1.17.0/src/StdConstants.sol";
import {
    DeployCandidate,
    DeployDeclaration,
    DeployDependency,
    DeploySuite,
    RainDeploySuitesBase
} from "rain-deploy-0.1.38/src/abstract/RainDeploySuitesBase.sol";
import {
    CREATION_CODE as TOFU_TOKEN_DECIMALS_CREATION_CODE_CANDIDATE,
    RUNTIME_CODE as TOFU_TOKEN_DECIMALS_RUNTIME_CODE_CANDIDATE
} from "../generated/candidate/TOFUTokenDecimals.sol";
import {LibRainDeploy} from "rain-deploy-0.1.38/src/lib/LibRainDeploy.sol";
import {LibRainDeployDeclaration} from "rain-deploy-0.1.38/src/lib/LibRainDeployDeclaration.sol";
import {LibRainDeploySnapshot, UnreleasableVersion} from "rain-deploy-0.1.38/src/lib/LibRainDeploySnapshot.sol";
import {LibRainDeployZoltuMechanism} from "rain-deploy-0.1.38/src/lib/LibRainDeployZoltuMechanism.sol";
import {LibTOFUTokenDecimalsDeploy} from "../lib/LibTOFUTokenDecimalsDeploy.sol";
import {LibReleasedSuites} from "../lib/LibReleasedSuites.sol";

/// @title TOFUTokenDecimalsDeploySuites
/// @notice Everything this repo deploys, declared ONCE: the hand-written
/// `tofu-token-decimals` candidate below, and the released side read from the
/// generated `LibReleasedSuites`, which `script/Build.sol` emits from the
/// frozen record.
///
/// It lives in `src/` rather than `test/` because `.soldeerignore` excludes
/// `test/` from the published package, and in a deploy repo the deployment
/// process is the product.
abstract contract TOFUTokenDecimalsDeploySuites is RainDeploySuitesBase {
    /// The newest release cut before rain-deploy 0.1.38 added `zerog` (0G
    /// mainnet, 16661) to every network roster.
    string constant LAST_RELEASE_BEFORE_ZEROG = "0_1_9";

    /// This repo's declaration: every Rain network, Zoltu, the generated
    /// releases narrowed by `narrowReleasedNetworks`, and
    /// `tofuTokenDecimalsCandidate()`.
    /// @return The declaration.
    function declaration() internal pure override returns (DeployDeclaration memory) {
        DeployDeclaration memory declared;
        LibRainDeployDeclaration.extend(declared);
        LibRainDeployZoltuMechanism.extend(declared);
        LibRainDeployDeclaration.addReleased(declared, narrowReleasedNetworks(LibReleasedSuites.releasedSuites()));
        DeployCandidate[] memory candidates = new DeployCandidate[](1);
        candidates[0] = tofuTokenDecimalsCandidate();
        LibRainDeployDeclaration.addCandidates(declared, candidates);
        return declared;
    }

    /// The roster every release up to `LAST_RELEASE_BEFORE_ZEROG` was cut and
    /// deployed for. Frozen: those releases are not required on a network
    /// added to rain-deploy later, even where a later deploy to the same
    /// address puts their code there.
    /// @return The network names.
    function networksBeforeZerog() internal pure returns (string[] memory) {
        string[] memory networks = new string[](9);
        networks[0] = LibRainDeploy.ARBITRUM_ONE;
        networks[1] = LibRainDeploy.BASE;
        networks[2] = LibRainDeploy.BASE_SEPOLIA;
        networks[3] = LibRainDeploy.BSC;
        networks[4] = LibRainDeploy.ETHEREUM;
        networks[5] = LibRainDeploy.FLARE;
        networks[6] = LibRainDeploy.HYPEREVM;
        networks[7] = LibRainDeploy.POLYGON;
        networks[8] = LibRainDeploy.ROBINHOOD;
        return networks;
    }

    /// The releases up to `LAST_RELEASE_BEFORE_ZEROG` that are deployed to
    /// `zerog` all the same, and so stay required there. Only
    /// `LAST_RELEASE_BEFORE_ZEROG` itself, the release dispatched to `zerog`:
    /// every release up to it shares its address and code, so that one deploy
    /// lands them all, but only it is required there.
    /// @return The release tags.
    function releasesOnZerog() internal pure returns (string[] memory) {
        string[] memory tags = new string[](1);
        tags[0] = LAST_RELEASE_BEFORE_ZEROG;
        return tags;
    }

    /// Sets each release up to `LAST_RELEASE_BEFORE_ZEROG` that is not in
    /// `releasesOnZerog()` to `networksBeforeZerog()`, leaving the rest to the
    /// declaration's networks, `zerog` included.
    ///
    /// rain-deploy 0.1.38 exports no helper for this. Its README ("Upgrading
    /// from 0.1.37") has each repo that deploys to 0G narrow its own releases
    /// as `RegistryDeploySuites.narrowReleasedNetworks` does, and that abstract
    /// is the registry repo's own declaration, so it cannot be inherited here.
    /// This follows it: the same roster, the same `isTag` refusal and the same
    /// `tagPrecedes` order.
    /// @param released The releases, mutated.
    /// @return `released`.
    function narrowReleasedNetworks(DeploySuite[] memory released) internal pure returns (DeploySuite[] memory) {
        for (uint256 i = 0; i < released.length; i++) {
            if (releasedBeforeZerog(released[i].suite) && !releasedOnZerog(released[i].suite)) {
                released[i].networks = networksBeforeZerog();
            }
        }
        return released;
    }

    /// Whether a suite key's tag is at or before `LAST_RELEASE_BEFORE_ZEROG`,
    /// ordered by `LibRainDeploySnapshot.tagPrecedes`. A key with no tag is
    /// not, and a tag that is not `isTag` is refused.
    /// @param suite The suite key.
    /// @return True if the release was cut before `zerog` joined the roster.
    function releasedBeforeZerog(string memory suite) internal pure returns (bool) {
        string memory tag = releaseTag(suite);
        return
            bytes(tag).length > 0 && !LibRainDeploySnapshot.tagPrecedes(StdConstants.VM, LAST_RELEASE_BEFORE_ZEROG, tag);
    }

    /// Whether a suite key's tag is one of `releasesOnZerog()`. A key with no
    /// tag is not, and a tag that is not `isTag` is refused.
    /// @param suite The suite key.
    /// @return True if the release is deployed to `zerog`.
    function releasedOnZerog(string memory suite) internal pure returns (bool) {
        bytes32 tag = keccak256(bytes(releaseTag(suite)));
        string[] memory tags = releasesOnZerog();
        for (uint256 i = 0; i < tags.length; i++) {
            if (keccak256(bytes(tags[i])) == tag) {
                return true;
            }
        }
        return false;
    }

    /// The tag half of a suite key, empty for a key with no tag, refusing
    /// `UnreleasableVersion` for one that is not `isTag`.
    /// @param suite The suite key.
    /// @return The tag.
    function releaseTag(string memory suite) internal pure returns (string memory) {
        bytes memory key = bytes(suite);
        uint256 start = bytes(suiteKeyName(suite)).length + 1;
        if (start > key.length) {
            return "";
        }
        bytes memory tag = new bytes(key.length - start);
        for (uint256 i = 0; i < tag.length; i++) {
            tag[i] = key[start + i];
        }
        if (!LibRainDeploySnapshot.isTag(string(tag))) {
            // `require-revert-in-loop` flags this, because the narrowing loop
            // reaches it, and it must: a key that is not a tag fails the whole
            // declaration rather than being skipped and required everywhere.
            // The disable names no lint because the forge rainix pins does not
            // know that id, and an unknown id is a warning under `-D warnings`.
            // forge-lint: disable-next-line
            revert UnreleasableVersion(string(tag));
        }
        return string(tag);
    }

    /// This repo's rolling `TOFUTokenDecimals` candidate. Named rather than
    /// reached by index into `declaration().candidates`, because `script/Build.sol`
    /// emits the released-suites lib from THIS candidate specifically, and
    /// naming it keeps the suite key, the artifact path and the dependency list
    /// spelled once.
    ///
    /// `TOFUTokenDecimals` has no constructor, and the only external contract
    /// it ever calls is the ERC20 the caller names at call time, so it has no
    /// dependency that must already be deployed.
    /// @return The candidate.
    function tofuTokenDecimalsCandidate() internal pure returns (DeployCandidate memory) {
        return DeployCandidate({
            snapshot: DeploySuite({
                suite: "tofu-token-decimals",
                creationCode: TOFU_TOKEN_DECIMALS_CREATION_CODE_CANDIDATE,
                storedDeployedAddress: LibTOFUTokenDecimalsDeploy.TOFU_TOKEN_DECIMALS_DEPLOYED_ADDRESS,
                storedBytecodeHash: LibTOFUTokenDecimalsDeploy.TOFU_TOKEN_DECIMALS_DEPLOYED_CODEHASH,
                storedRuntimeCode: TOFU_TOKEN_DECIMALS_RUNTIME_CODE_CANDIDATE,
                artifactPath: "src/concrete/TOFUTokenDecimals.sol:TOFUTokenDecimals",
                dependencies: new DeployDependency[](0),
                mechanismData: LibRainDeployZoltuMechanism.mechanismData(),
                networks: new string[](0),
                describedByMeta: ""
            }),
            unanchorableReason: ""
        });
    }
}
