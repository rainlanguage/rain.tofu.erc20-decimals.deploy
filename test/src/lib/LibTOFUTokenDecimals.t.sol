// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {TOFUTokenDecimals} from "src/concrete/TOFUTokenDecimals.sol";
import {LibTOFUTokenDecimals} from "rain-tofu-erc20-decimals-0.1.3/src/lib/LibTOFUTokenDecimals.sol";
import {LibRainDeploy} from "rain-deploy-0.1.7/src/lib/LibRainDeploy.sol";
import {LibExtrospectMetamorphic} from "rain-extrospection-0.1.13/src/lib/LibExtrospectMetamorphic.sol";
import {LibExtrospectBytecode} from "rain-extrospection-0.1.13/src/lib/LibExtrospectBytecode.sol";
import {Test} from "forge-std-1.16.2/src/Test.sol";

/// @title LibTOFUTokenDecimalsTest
/// @notice The cross-repo tie: the `rain-tofu-erc20-decimals` library half ships
/// `LibTOFUTokenDecimals` with the singleton's address, code hash and creation
/// code baked in as constants, and THIS repo is the one that compiles the
/// singleton those constants describe. Nothing in the library half can check
/// them — it has no concrete to check them against — so the assertions live
/// here, where `type(TOFUTokenDecimals).creationCode` exists.
///
/// The library's revert-path tests (`ensureDeployed` on an empty or wrong-code
/// address) need no concrete and stay in the library half.
contract LibTOFUTokenDecimalsTest is Test {
    /// Zoltu-deploying this repo's `TOFUTokenDecimals` lands on the address the
    /// library half pins, and `ensureDeployed` then accepts it.
    function testDeployAddress() external {
        // Etched locally rather than forked: the Zoltu factory is the only
        // chain state this needs, and etching it makes the suite deterministic
        // and RPC-free.
        LibRainDeploy.etchZoltuFactory(vm);
        address deployedAddress = LibRainDeploy.deployZoltu(type(TOFUTokenDecimals).creationCode);
        assertEq(deployedAddress, address(LibTOFUTokenDecimals.TOFU_DECIMALS_DEPLOYMENT));

        // Check that ensure deployed finds the contract correctly.
        LibTOFUTokenDecimals.ensureDeployed();
    }

    /// The singleton bytecode must not contain any reachable metamorphic
    /// opcodes (SELFDESTRUCT, DELEGATECALL, CALLCODE, CREATE, CREATE2).
    /// This ensures the code at the singleton address cannot change after
    /// deployment, eliminating the theoretical TOCTOU gap between
    /// ensureDeployed() and the subsequent external call.
    function testNotMetamorphic() external {
        TOFUTokenDecimals singleton = new TOFUTokenDecimals();
        LibExtrospectMetamorphic.checkNotMetamorphic(address(singleton).code);
    }

    /// The singleton must be compiled without CBOR metadata
    /// (`cbor_metadata = false` in foundry.toml). CBOR metadata includes a
    /// content hash of the source, which an attacker could exploit for
    /// metamorphic-style address reuse if the factory doesn't account for it.
    function testNoCBORMetadata() external {
        TOFUTokenDecimals singleton = new TOFUTokenDecimals();
        LibExtrospectBytecode.checkNoSolidityCBORMetadata(address(singleton));
    }

    function testExpectedCodeHash() external {
        TOFUTokenDecimals tofuTokenDecimals = new TOFUTokenDecimals();

        assertEq(address(tofuTokenDecimals).codehash, LibTOFUTokenDecimals.TOFU_DECIMALS_EXPECTED_CODE_HASH);
    }

    function testExpectedCreationCode() external pure {
        assertEq(type(TOFUTokenDecimals).creationCode, LibTOFUTokenDecimals.TOFU_DECIMALS_EXPECTED_CREATION_CODE);
    }
}
