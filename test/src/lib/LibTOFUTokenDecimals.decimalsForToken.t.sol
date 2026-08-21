// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {LibTOFUTokenDecimals, TOFUOutcome} from "rain-tofu-erc20-decimals-0.1.3/src/lib/LibTOFUTokenDecimals.sol";
import {LibRainDeploy} from "rain-deploy-0.1.7/src/lib/LibRainDeploy.sol";
import {TOFUTokenDecimals} from "src/concrete/TOFUTokenDecimals.sol";
import {IERC20} from "forge-std-1.16.2/src/interfaces/IERC20.sol";

contract LibTOFUTokenDecimalsDecimalsForTokenTest is Test {
    constructor() {
        // Etched locally rather than forked: the Zoltu factory is the only
        // chain state this needs, and etching it makes the suite deterministic
        // and RPC-free.
        LibRainDeploy.etchZoltuFactory(vm);
        address deployedAddress = LibRainDeploy.deployZoltu(type(TOFUTokenDecimals).creationCode);
        assertEq(deployedAddress, address(LibTOFUTokenDecimals.TOFU_DECIMALS_DEPLOYMENT));

        // Check that ensure deployed finds the contract correctly.
        LibTOFUTokenDecimals.ensureDeployed();
    }

    function testDecimalsForTokenAddressZero() external {
        (TOFUOutcome tofuOutcome, uint8 decimals) = LibTOFUTokenDecimals.decimalsForToken(address(0));
        assertEq(uint256(tofuOutcome), uint256(TOFUOutcome.ReadFailure));
        assertEq(decimals, 0);
    }

    function testDecimalsForTokenValidValue(uint8 decimalsA, uint8 decimalsB) external {
        address token = makeAddr("TokenA");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimalsA));

        (TOFUOutcome tofuOutcome, uint8 readDecimals) = LibTOFUTokenDecimals.decimalsForToken(token);
        assertEq(uint256(tofuOutcome), uint256(TOFUOutcome.Initial));
        assertEq(readDecimals, decimalsA);

        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimalsB));
        (tofuOutcome, readDecimals) = LibTOFUTokenDecimals.decimalsForToken(token);
        if (decimalsA == decimalsB) {
            assertEq(uint256(tofuOutcome), uint256(TOFUOutcome.Consistent));
            assertEq(readDecimals, decimalsA);
        } else {
            assertEq(uint256(tofuOutcome), uint256(TOFUOutcome.Inconsistent));
            assertEq(readDecimals, decimalsA);
        }
    }

    function testDecimalsForTokenInvalidValueTooLarge(uint256 decimals) external {
        vm.assume(decimals > 0xff);
        address token = makeAddr("TokenB");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));
        (TOFUOutcome tofuOutcome, uint8 readDecimals) = LibTOFUTokenDecimals.decimalsForToken(token);
        assertEq(uint256(tofuOutcome), uint256(TOFUOutcome.ReadFailure));
        assertEq(readDecimals, 0);
    }

    function testDecimalsForTokenInvalidValueTooLargeInitialized(uint8 storedDecimals, uint256 decimals) external {
        vm.assume(decimals > 0xff);
        address token = makeAddr("TokenB");

        // Initialize storage first.
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(storedDecimals));
        (TOFUOutcome tofuOutcome, uint8 readDecimals) = LibTOFUTokenDecimals.decimalsForToken(token);
        assertEq(uint256(tofuOutcome), uint256(TOFUOutcome.Initial));
        assertEq(readDecimals, storedDecimals);

        // Now mock an invalid value.
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));
        (tofuOutcome, readDecimals) = LibTOFUTokenDecimals.decimalsForToken(token);
        assertEq(uint256(tofuOutcome), uint256(TOFUOutcome.ReadFailure));
        assertEq(readDecimals, storedDecimals);
    }

    function testDecimalsForTokenInvalidValueNotEnoughData(bytes memory data, uint256 length) external {
        length = bound(length, 0, 0x1f);
        if (data.length > length) {
            assembly ("memory-safe") {
                mstore(data, length)
            }
        }
        address token = makeAddr("TokenC");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), data);

        (TOFUOutcome tofuOutcome, uint8 readDecimals) = LibTOFUTokenDecimals.decimalsForToken(token);
        assertEq(uint256(tofuOutcome), uint256(TOFUOutcome.ReadFailure));
        assertEq(readDecimals, 0);
    }

    function testDecimalsForTokenInvalidValueNotEnoughDataInitialized(
        uint8 storedDecimals,
        bytes memory data,
        uint256 length
    ) external {
        length = bound(length, 0, 0x1f);
        if (data.length > length) {
            assembly ("memory-safe") {
                mstore(data, length)
            }
        }
        address token = makeAddr("TokenC");

        // Initialize storage first.
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(storedDecimals));
        (TOFUOutcome tofuOutcome, uint8 readDecimals) = LibTOFUTokenDecimals.decimalsForToken(token);
        assertEq(uint256(tofuOutcome), uint256(TOFUOutcome.Initial));
        assertEq(readDecimals, storedDecimals);

        // Now mock invalid data.
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), data);
        (tofuOutcome, readDecimals) = LibTOFUTokenDecimals.decimalsForToken(token);
        assertEq(uint256(tofuOutcome), uint256(TOFUOutcome.ReadFailure));
        assertEq(readDecimals, storedDecimals);
    }

    function testDecimalsForTokenTokenContractRevert() external {
        address token = makeAddr("TokenD");
        vm.etch(token, hex"fd");
        (TOFUOutcome tofuOutcome, uint8 readDecimals) = LibTOFUTokenDecimals.decimalsForToken(token);
        assertEq(uint256(tofuOutcome), uint256(TOFUOutcome.ReadFailure));
        assertEq(readDecimals, 0);
    }

    function testDecimalsForTokenTokenContractRevertInitialized(uint8 storedDecimals) external {
        address token = makeAddr("TokenD");

        // Initialize storage first.
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(storedDecimals));
        (TOFUOutcome tofuOutcome, uint8 readDecimals) = LibTOFUTokenDecimals.decimalsForToken(token);
        assertEq(uint256(tofuOutcome), uint256(TOFUOutcome.Initial));
        assertEq(readDecimals, storedDecimals);

        // Clear mocks so the etch takes effect.
        vm.clearMockedCalls();
        // Now make the token revert.
        vm.etch(token, hex"fd");
        (tofuOutcome, readDecimals) = LibTOFUTokenDecimals.decimalsForToken(token);
        assertEq(uint256(tofuOutcome), uint256(TOFUOutcome.ReadFailure));
        assertEq(readDecimals, storedDecimals);
    }
}
