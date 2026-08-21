// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {LibTOFUTokenDecimals, TOFUOutcome} from "rain-tofu-erc20-decimals-0.1.3/src/lib/LibTOFUTokenDecimals.sol";
import {LibRainDeploy} from "rain-deploy-0.1.7/src/lib/LibRainDeploy.sol";
import {TOFUTokenDecimals} from "src/concrete/TOFUTokenDecimals.sol";

/// Integration tests that call the library against real mainnet ERC20 tokens
/// on a fork. Validates that the inline assembly `staticcall` works correctly
/// with real-world ABI encoding, not just `vm.mockCall` mocks.
contract LibTOFUTokenDecimalsRealTokensTest is Test {
    /// Arbitrum WETH — 18 decimals.
    address internal constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    /// Arbitrum native USDC — 6 decimals.
    address internal constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    /// Arbitrum WBTC — 8 decimals.
    address internal constant WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    /// Arbitrum DAI — 18 decimals.
    address internal constant DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

    /// Pinned *below* the block at which `TOFUTokenDecimals` was deployed to
    /// Arbitrum, and it has to stay below it. The constructor Zoltu-deploys the
    /// singleton at its deterministic address, and that only succeeds while the
    /// address is empty. The singleton is live on Arbitrum today — the library
    /// repo's `LibTOFUTokenDecimals.prod.t.sol` forks the chain tip and asserts
    /// exactly that — so at any block after the deployment `CREATE2` returns
    /// zero, `deployZoltu` reverts `DeployFailed`, and every test in this file
    /// fails in the constructor. Do NOT bump this toward the tip. Etching the
    /// Zoltu factory does not rescue it either: the collision is at the
    /// singleton's address, not the factory's. If the RPC stops serving this
    /// block, move to another block that is still before the deployment and at
    /// which WETH, USDC, WBTC and DAI are all live.
    uint256 internal constant FORK_BLOCK_NUMBER = 280_000_000;

    constructor() {
        vm.createSelectFork("arbitrum", FORK_BLOCK_NUMBER);
        address deployedAddress = LibRainDeploy.deployZoltu(type(TOFUTokenDecimals).creationCode);
        assertEq(deployedAddress, address(LibTOFUTokenDecimals.TOFU_DECIMALS_DEPLOYMENT));
        LibTOFUTokenDecimals.ensureDeployed();
    }

    /// WETH returns 18 decimals on initial read and consistent on re-read.
    function testRealTokenWETH() external {
        (TOFUOutcome outcome, uint8 decimals) = LibTOFUTokenDecimals.decimalsForToken(WETH);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Initial));
        assertEq(decimals, 18);

        (outcome, decimals) = LibTOFUTokenDecimals.decimalsForToken(WETH);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Consistent));
        assertEq(decimals, 18);
    }

    /// USDC returns 6 decimals on initial read and consistent on re-read.
    function testRealTokenUSDC() external {
        (TOFUOutcome outcome, uint8 decimals) = LibTOFUTokenDecimals.decimalsForToken(USDC);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Initial));
        assertEq(decimals, 6);

        (outcome, decimals) = LibTOFUTokenDecimals.decimalsForToken(USDC);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Consistent));
        assertEq(decimals, 6);
    }

    /// WBTC returns 8 decimals on initial read and consistent on re-read.
    function testRealTokenWBTC() external {
        (TOFUOutcome outcome, uint8 decimals) = LibTOFUTokenDecimals.decimalsForToken(WBTC);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Initial));
        assertEq(decimals, 8);

        (outcome, decimals) = LibTOFUTokenDecimals.decimalsForToken(WBTC);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Consistent));
        assertEq(decimals, 8);
    }

    /// DAI returns 18 decimals on initial read and consistent on re-read.
    function testRealTokenDAI() external {
        (TOFUOutcome outcome, uint8 decimals) = LibTOFUTokenDecimals.decimalsForToken(DAI);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Initial));
        assertEq(decimals, 18);

        (outcome, decimals) = LibTOFUTokenDecimals.decimalsForToken(DAI);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Consistent));
        assertEq(decimals, 18);
    }

    /// decimalsForTokenReadOnly returns Initial then Consistent for WETH.
    function testRealTokenDecimalsForTokenReadOnlyWETH() external {
        (TOFUOutcome outcome, uint8 decimals) = LibTOFUTokenDecimals.decimalsForTokenReadOnly(WETH);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Initial));
        assertEq(decimals, 18);

        LibTOFUTokenDecimals.decimalsForToken(WETH);

        (outcome, decimals) = LibTOFUTokenDecimals.decimalsForTokenReadOnly(WETH);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Consistent));
        assertEq(decimals, 18);
    }

    /// decimalsForTokenReadOnly returns Initial then Consistent for USDC.
    function testRealTokenDecimalsForTokenReadOnlyUSDC() external {
        (TOFUOutcome outcome, uint8 decimals) = LibTOFUTokenDecimals.decimalsForTokenReadOnly(USDC);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Initial));
        assertEq(decimals, 6);

        LibTOFUTokenDecimals.decimalsForToken(USDC);

        (outcome, decimals) = LibTOFUTokenDecimals.decimalsForTokenReadOnly(USDC);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Consistent));
        assertEq(decimals, 6);
    }

    /// decimalsForTokenReadOnly returns Initial then Consistent for WBTC.
    function testRealTokenDecimalsForTokenReadOnlyWBTC() external {
        (TOFUOutcome outcome, uint8 decimals) = LibTOFUTokenDecimals.decimalsForTokenReadOnly(WBTC);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Initial));
        assertEq(decimals, 8);

        LibTOFUTokenDecimals.decimalsForToken(WBTC);

        (outcome, decimals) = LibTOFUTokenDecimals.decimalsForTokenReadOnly(WBTC);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Consistent));
        assertEq(decimals, 8);
    }

    /// decimalsForTokenReadOnly returns Initial then Consistent for DAI.
    function testRealTokenDecimalsForTokenReadOnlyDAI() external {
        (TOFUOutcome outcome, uint8 decimals) = LibTOFUTokenDecimals.decimalsForTokenReadOnly(DAI);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Initial));
        assertEq(decimals, 18);

        LibTOFUTokenDecimals.decimalsForToken(DAI);

        (outcome, decimals) = LibTOFUTokenDecimals.decimalsForTokenReadOnly(DAI);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Consistent));
        assertEq(decimals, 18);
    }

    /// safeDecimalsForToken succeeds on WETH.
    function testRealTokenSafeDecimalsForTokenWETH() external {
        uint8 decimals = LibTOFUTokenDecimals.safeDecimalsForToken(WETH);
        assertEq(decimals, 18);

        decimals = LibTOFUTokenDecimals.safeDecimalsForToken(WETH);
        assertEq(decimals, 18);
    }

    /// safeDecimalsForToken succeeds on USDC.
    function testRealTokenSafeDecimalsForTokenUSDC() external {
        uint8 decimals = LibTOFUTokenDecimals.safeDecimalsForToken(USDC);
        assertEq(decimals, 6);

        decimals = LibTOFUTokenDecimals.safeDecimalsForToken(USDC);
        assertEq(decimals, 6);
    }

    /// safeDecimalsForToken succeeds on WBTC.
    function testRealTokenSafeDecimalsForTokenWBTC() external {
        uint8 decimals = LibTOFUTokenDecimals.safeDecimalsForToken(WBTC);
        assertEq(decimals, 8);

        decimals = LibTOFUTokenDecimals.safeDecimalsForToken(WBTC);
        assertEq(decimals, 8);
    }

    /// safeDecimalsForToken succeeds on DAI.
    function testRealTokenSafeDecimalsForTokenDAI() external {
        uint8 decimals = LibTOFUTokenDecimals.safeDecimalsForToken(DAI);
        assertEq(decimals, 18);

        decimals = LibTOFUTokenDecimals.safeDecimalsForToken(DAI);
        assertEq(decimals, 18);
    }

    /// safeDecimalsForTokenReadOnly succeeds on WETH.
    function testRealTokenSafeDecimalsForTokenReadOnlyWETH() external {
        uint8 decimals = LibTOFUTokenDecimals.safeDecimalsForTokenReadOnly(WETH);
        assertEq(decimals, 18);

        LibTOFUTokenDecimals.decimalsForToken(WETH);

        decimals = LibTOFUTokenDecimals.safeDecimalsForTokenReadOnly(WETH);
        assertEq(decimals, 18);
    }

    /// safeDecimalsForTokenReadOnly succeeds on USDC.
    function testRealTokenSafeDecimalsForTokenReadOnlyUSDC() external {
        uint8 decimals = LibTOFUTokenDecimals.safeDecimalsForTokenReadOnly(USDC);
        assertEq(decimals, 6);

        LibTOFUTokenDecimals.decimalsForToken(USDC);

        decimals = LibTOFUTokenDecimals.safeDecimalsForTokenReadOnly(USDC);
        assertEq(decimals, 6);
    }

    /// safeDecimalsForTokenReadOnly succeeds on WBTC.
    function testRealTokenSafeDecimalsForTokenReadOnlyWBTC() external {
        uint8 decimals = LibTOFUTokenDecimals.safeDecimalsForTokenReadOnly(WBTC);
        assertEq(decimals, 8);

        LibTOFUTokenDecimals.decimalsForToken(WBTC);

        decimals = LibTOFUTokenDecimals.safeDecimalsForTokenReadOnly(WBTC);
        assertEq(decimals, 8);
    }

    /// safeDecimalsForTokenReadOnly succeeds on DAI.
    function testRealTokenSafeDecimalsForTokenReadOnlyDAI() external {
        uint8 decimals = LibTOFUTokenDecimals.safeDecimalsForTokenReadOnly(DAI);
        assertEq(decimals, 18);

        LibTOFUTokenDecimals.decimalsForToken(DAI);

        decimals = LibTOFUTokenDecimals.safeDecimalsForTokenReadOnly(DAI);
        assertEq(decimals, 18);
    }

    /// Cross-token isolation: initializing multiple real tokens does not
    /// cross-contaminate storage.
    function testRealTokenCrossTokenIsolation() external {
        LibTOFUTokenDecimals.decimalsForToken(WETH);
        LibTOFUTokenDecimals.decimalsForToken(USDC);

        (TOFUOutcome outcome, uint8 decimals) = LibTOFUTokenDecimals.decimalsForToken(WETH);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Consistent));
        assertEq(decimals, 18);

        (outcome, decimals) = LibTOFUTokenDecimals.decimalsForToken(USDC);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Consistent));
        assertEq(decimals, 6);
    }
}
