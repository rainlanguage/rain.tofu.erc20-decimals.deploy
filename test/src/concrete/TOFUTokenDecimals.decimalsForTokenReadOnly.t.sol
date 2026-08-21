// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {TOFUTokenDecimals} from "src/concrete/TOFUTokenDecimals.sol";
import {TOFUOutcome} from "rain-tofu-erc20-decimals-0.1.3/src/interface/ITOFUTokenDecimals.sol";
import {IERC20} from "forge-std-1.16.2/src/interfaces/IERC20.sol";

/// Smoke test for the TOFUTokenDecimals concrete contract's
/// decimalsForTokenReadOnly. Verifies the pass-through wiring to
/// LibTOFUTokenDecimalsImplementation without a fork.
contract TOFUTokenDecimalsDecimalsForTokenReadOnlyTest is Test {
    TOFUTokenDecimals internal concrete;

    function setUp() external {
        concrete = new TOFUTokenDecimals();
    }

    /// Calling with `address(0)` produces `ReadFailure` with zero decimals.
    function testDecimalsForTokenReadOnlyAddressZero() external {
        (TOFUOutcome outcome, uint8 result) = concrete.decimalsForTokenReadOnly(address(0));
        assertEq(uint256(outcome), uint256(TOFUOutcome.ReadFailure));
        assertEq(result, 0);
    }

    /// Read-only call on an uninitialized token returns `Initial` with the
    /// freshly read decimals value.
    function testDecimalsForTokenReadOnly(uint8 decimals) external {
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));

        (TOFUOutcome outcome, uint8 result) = concrete.decimalsForTokenReadOnly(token);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Initial));
        assertEq(result, decimals);
    }

    /// Explicit boundary test for `decimals=0`. Proves the `initialized`
    /// flag distinguishes stored zero from uninitialized storage: read-only
    /// sees `Initial`, then `Consistent` after stateful initialization.
    function testDecimalsForTokenReadOnlyDecimalsZero() external {
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(uint8(0)));

        (TOFUOutcome outcome, uint8 result) = concrete.decimalsForTokenReadOnly(token);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Initial));
        assertEq(result, 0);

        concrete.decimalsForToken(token);

        (outcome, result) = concrete.decimalsForTokenReadOnly(token);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Consistent));
        assertEq(result, 0);
    }

    /// Read-only call after initialization with matching decimals returns
    /// `Consistent` and the stored value.
    function testDecimalsForTokenReadOnlyConsistent(uint8 decimals) external {
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));

        concrete.decimalsForToken(token);

        (TOFUOutcome outcome, uint8 result) = concrete.decimalsForTokenReadOnly(token);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Consistent));
        assertEq(result, decimals);
    }

    /// Read-only call after initialization with differing decimals returns
    /// `Inconsistent` and the originally stored value.
    function testDecimalsForTokenReadOnlyInconsistent(uint8 decimalsA, uint8 decimalsB) external {
        vm.assume(decimalsA != decimalsB);
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimalsA));

        concrete.decimalsForToken(token);

        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimalsB));

        (TOFUOutcome outcome, uint8 result) = concrete.decimalsForTokenReadOnly(token);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Inconsistent));
        assertEq(result, decimalsA);
    }

    /// A reverting token produces `ReadFailure` with zero decimals when
    /// uninitialized.
    function testDecimalsForTokenReadOnlyReadFailure() external {
        address token = makeAddr("token");
        vm.mockCallRevert(token, abi.encodeWithSelector(IERC20.decimals.selector), "");

        (TOFUOutcome outcome, uint8 result) = concrete.decimalsForTokenReadOnly(token);
        assertEq(uint256(outcome), uint256(TOFUOutcome.ReadFailure));
        assertEq(result, 0);
    }

    /// A reverting token produces `ReadFailure` with the stored decimals
    /// when the token was previously initialized.
    function testDecimalsForTokenReadOnlyReadFailureInitialized(uint8 decimals) external {
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));

        concrete.decimalsForToken(token);

        vm.mockCallRevert(token, abi.encodeWithSelector(IERC20.decimals.selector), "");

        (TOFUOutcome outcome, uint8 result) = concrete.decimalsForTokenReadOnly(token);
        assertEq(uint256(outcome), uint256(TOFUOutcome.ReadFailure));
        assertEq(result, decimals);
    }

    /// A token returning a value larger than `uint8` from `decimals()` is
    /// treated as `ReadFailure` via the `gt(readDecimals, 0xff)` guard.
    function testDecimalsForTokenReadOnlyOverwideDecimals(uint256 decimals) external {
        vm.assume(decimals > 0xff);
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));

        (TOFUOutcome outcome, uint8 result) = concrete.decimalsForTokenReadOnly(token);
        assertEq(uint256(outcome), uint256(TOFUOutcome.ReadFailure));
        assertEq(result, 0);
    }

    /// A contract with code but no `decimals()` function (STOP opcode only)
    /// produces `ReadFailure` via the `returndatasize < 0x20` guard.
    function testDecimalsForTokenReadOnlyNoDecimalsFunction() external {
        address token = makeAddr("token");
        vm.etch(token, hex"00");

        (TOFUOutcome outcome, uint8 result) = concrete.decimalsForTokenReadOnly(token);
        assertEq(uint256(outcome), uint256(TOFUOutcome.ReadFailure));
        assertEq(result, 0);
    }

    /// Calling `decimalsForTokenReadOnly` does not persist state; a
    /// subsequent stateful call still sees `Initial`.
    function testDecimalsForTokenReadOnlyDoesNotWriteStorage(uint8 decimals) external {
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));

        concrete.decimalsForTokenReadOnly(token);

        (TOFUOutcome outcome,) = concrete.decimalsForToken(token);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Initial));
    }
}
