// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {TOFUTokenDecimals} from "src/concrete/TOFUTokenDecimals.sol";
import {LibTOFUTokenDecimals, TOFUOutcome} from "rain-tofu-erc20-decimals-0.1.3/src/lib/LibTOFUTokenDecimals.sol";
import {LibRainDeploy} from "rain-deploy-0.1.7/src/lib/LibRainDeploy.sol";
import {Test} from "forge-std-1.16.2/src/Test.sol";
import {IERC20} from "forge-std-1.16.2/src/interfaces/IERC20.sol";

contract LibTOFUTokenDecimalsDecimalsForTokenReadOnlyTest is Test {
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

    function testDecimalsForTokenReadOnlyAddressZero() external view {
        (TOFUOutcome tofuOutcome, uint8 decimals) = LibTOFUTokenDecimals.decimalsForTokenReadOnly(address(0));
        assertEq(uint256(tofuOutcome), uint256(TOFUOutcome.ReadFailure));
        assertEq(decimals, 0);
    }

    function testDecimalsForTokenReadOnlyValidValue(uint8 decimalsA, uint8 decimalsB) external {
        address token = makeAddr("TokenA");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimalsA));

        (TOFUOutcome tofuOutcome, uint8 readDecimals) = LibTOFUTokenDecimals.decimalsForTokenReadOnly(token);
        assertEq(uint256(tofuOutcome), uint256(TOFUOutcome.Initial));
        assertEq(readDecimals, decimalsA);

        // As this is read only we are still uninitialized so always get initial
        // back again.
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimalsB));
        (tofuOutcome, readDecimals) = LibTOFUTokenDecimals.decimalsForTokenReadOnly(token);
        assertEq(uint256(tofuOutcome), uint256(TOFUOutcome.Initial));
        assertEq(readDecimals, decimalsB);
    }

    function testDecimalsForTokenReadOnlyConsistentInconsistent(uint8 decimalsA, uint8 decimalsB) external {
        address token = makeAddr("TokenA");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimalsA));

        // Initialize storage via the stateful variant.
        LibTOFUTokenDecimals.decimalsForToken(token);

        // Now read-only should see Consistent or Inconsistent.
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimalsB));
        (TOFUOutcome tofuOutcome, uint8 readDecimals) = LibTOFUTokenDecimals.decimalsForTokenReadOnly(token);
        if (decimalsA == decimalsB) {
            assertEq(uint256(tofuOutcome), uint256(TOFUOutcome.Consistent));
            assertEq(readDecimals, decimalsA);
        } else {
            assertEq(uint256(tofuOutcome), uint256(TOFUOutcome.Inconsistent));
            assertEq(readDecimals, decimalsA);
        }
    }

    /// Read-only must not write storage. Calling decimalsForTokenReadOnly
    /// then decimalsForToken must still produce Initial from the stateful
    /// call, proving the read-only call did not initialize storage.
    function testDecimalsForTokenReadOnlyDoesNotWriteStorage(uint8 decimals) external {
        address token = makeAddr("TokenRO");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));

        // Read-only call.
        (TOFUOutcome tofuOutcome,) = LibTOFUTokenDecimals.decimalsForTokenReadOnly(token);
        assertEq(uint256(tofuOutcome), uint256(TOFUOutcome.Initial));

        // Stateful call must still see Initial.
        (tofuOutcome,) = LibTOFUTokenDecimals.decimalsForToken(token);
        assertEq(uint256(tofuOutcome), uint256(TOFUOutcome.Initial));
    }

    function testDecimalsForTokenReadOnlyInvalidValueTooLarge(uint256 decimals) external {
        vm.assume(decimals > 0xff);
        address token = makeAddr("TokenB");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));
        (TOFUOutcome tofuOutcome, uint8 readDecimals) = LibTOFUTokenDecimals.decimalsForTokenReadOnly(token);
        assertEq(uint256(tofuOutcome), uint256(TOFUOutcome.ReadFailure));
        assertEq(readDecimals, 0);
    }

    function testDecimalsForTokenReadOnlyInvalidValueTooLargeInitialized(uint8 storedDecimals, uint256 decimals)
        external
    {
        vm.assume(decimals > 0xff);
        address token = makeAddr("TokenB");

        // Initialize storage first.
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(storedDecimals));
        LibTOFUTokenDecimals.decimalsForToken(token);

        // Now mock an invalid value.
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));
        (TOFUOutcome tofuOutcome, uint8 readDecimals) = LibTOFUTokenDecimals.decimalsForTokenReadOnly(token);
        assertEq(uint256(tofuOutcome), uint256(TOFUOutcome.ReadFailure));
        assertEq(readDecimals, storedDecimals);
    }

    function testDecimalsForTokenReadOnlyInvalidValueNotEnoughData(bytes memory data, uint256 length) external {
        length = bound(length, 0, 0x1f);
        if (data.length > length) {
            assembly ("memory-safe") {
                mstore(data, length)
            }
        }
        address token = makeAddr("TokenC");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), data);
        (TOFUOutcome tofuOutcome, uint8 readDecimals) = LibTOFUTokenDecimals.decimalsForTokenReadOnly(token);
        assertEq(uint256(tofuOutcome), uint256(TOFUOutcome.ReadFailure));
        assertEq(readDecimals, 0);
    }

    function testDecimalsForTokenReadOnlyInvalidValueNotEnoughDataInitialized(
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
        LibTOFUTokenDecimals.decimalsForToken(token);

        // Now mock invalid data.
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), data);
        (TOFUOutcome tofuOutcome, uint8 readDecimals) = LibTOFUTokenDecimals.decimalsForTokenReadOnly(token);
        assertEq(uint256(tofuOutcome), uint256(TOFUOutcome.ReadFailure));
        assertEq(readDecimals, storedDecimals);
    }

    function testDecimalsForTokenReadOnlyTokenContractRevert() external {
        address token = makeAddr("TokenD");
        vm.etch(token, hex"fd");
        (TOFUOutcome tofuOutcome, uint8 readDecimals) = LibTOFUTokenDecimals.decimalsForTokenReadOnly(token);
        assertEq(uint256(tofuOutcome), uint256(TOFUOutcome.ReadFailure));
        assertEq(readDecimals, 0);
    }

    function testDecimalsForTokenReadOnlyTokenContractRevertInitialized(uint8 storedDecimals) external {
        address token = makeAddr("TokenD");

        // Initialize storage first.
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(storedDecimals));
        LibTOFUTokenDecimals.decimalsForToken(token);

        // Clear mocks so the etch takes effect.
        vm.clearMockedCalls();
        // Now make the token revert.
        vm.etch(token, hex"fd");
        (TOFUOutcome tofuOutcome, uint8 readDecimals) = LibTOFUTokenDecimals.decimalsForTokenReadOnly(token);
        assertEq(uint256(tofuOutcome), uint256(TOFUOutcome.ReadFailure));
        assertEq(readDecimals, storedDecimals);
    }
}
