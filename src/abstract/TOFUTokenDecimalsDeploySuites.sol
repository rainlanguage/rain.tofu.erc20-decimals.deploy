// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {
    DeployCandidate,
    DeployDeclaration,
    DeployDependency,
    DeploySuite,
    RainDeploySuitesBase
} from "rain-deploy-0.1.35/src/abstract/RainDeploySuitesBase.sol";
import {
    CREATION_CODE as TOFU_TOKEN_DECIMALS_CREATION_CODE_CANDIDATE,
    RUNTIME_CODE as TOFU_TOKEN_DECIMALS_RUNTIME_CODE_CANDIDATE
} from "../generated/candidate/TOFUTokenDecimals.sol";
import {LibRainDeployDeclaration} from "rain-deploy-0.1.35/src/lib/LibRainDeployDeclaration.sol";
import {LibRainDeployZoltuMechanism} from "rain-deploy-0.1.35/src/lib/LibRainDeployZoltuMechanism.sol";
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
    /// @inheritdoc RainDeploySuitesBase
    function declaration() internal pure override returns (DeployDeclaration memory) {
        DeployDeclaration memory declared;
        LibRainDeployDeclaration.extend(declared);
        LibRainDeployZoltuMechanism.extend(declared);
        LibRainDeployDeclaration.addReleased(declared, LibReleasedSuites.releasedSuites());
        DeployCandidate[] memory candidates = new DeployCandidate[](1);
        candidates[0] = tofuTokenDecimalsCandidate();
        LibRainDeployDeclaration.addCandidates(declared, candidates);
        return declared;
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
