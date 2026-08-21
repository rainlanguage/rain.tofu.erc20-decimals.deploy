// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {TOFUTokenDecimals} from "src/concrete/TOFUTokenDecimals.sol";
import {TOFUOutcome, ITOFUTokenDecimals} from "rain-tofu-erc20-decimals-0.1.3/src/interface/ITOFUTokenDecimals.sol";
import {IERC20} from "forge-std-1.16.2/src/interfaces/IERC20.sol";

/// Smoke test for the TOFUTokenDecimals concrete contract's
/// safeDecimalsForTokenReadOnly. Verifies the pass-through wiring to
/// LibTOFUTokenDecimalsImplementation without a fork.
contract TOFUTokenDecimalsSafeDecimalsForTokenReadOnlyTest is Test {
    TOFUTokenDecimals internal concrete;

    function setUp() external {
        concrete = new TOFUTokenDecimals();
    }

    /// Calling with `address(0)` reverts with `TokenDecimalsReadFailure`.
    function testSafeDecimalsForTokenReadOnlyAddressZeroReverts() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                ITOFUTokenDecimals.TokenDecimalsReadFailure.selector, address(0), TOFUOutcome.ReadFailure
            )
        );
        concrete.safeDecimalsForTokenReadOnly(address(0));
    }

    /// Explicit boundary test for `decimals=0`. Proves the `initialized`
    /// flag distinguishes stored zero from uninitialized storage: read-only
    /// safe call succeeds on `Initial`, then succeeds on `Consistent` after
    /// stateful initialization.
    function testSafeDecimalsForTokenReadOnlyDecimalsZero() external {
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(uint8(0)));

        uint8 result = concrete.safeDecimalsForTokenReadOnly(token);
        assertEq(result, 0);

        concrete.decimalsForToken(token);

        result = concrete.safeDecimalsForTokenReadOnly(token);
        assertEq(result, 0);
    }

    /// After initialization, read-only safe call with matching decimals
    /// succeeds.
    function testSafeDecimalsForTokenReadOnly(uint8 decimals) external {
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));

        // Initialize state first so read-only has something to check against.
        concrete.decimalsForToken(token);

        uint8 result = concrete.safeDecimalsForTokenReadOnly(token);
        assertEq(result, decimals);
    }

    /// Without prior initialization, read-only safe call succeeds on the
    /// `Initial` path and returns the freshly read decimals value.
    function testSafeDecimalsForTokenReadOnlyInitial(uint8 decimals) external {
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));

        uint8 result = concrete.safeDecimalsForTokenReadOnly(token);
        assertEq(result, decimals);
    }

    /// After initialization with different decimals, read-only safe call
    /// reverts with `TokenDecimalsReadFailure` and the `Inconsistent` outcome.
    function testSafeDecimalsForTokenReadOnlyInconsistentReverts(uint8 decimalsA, uint8 decimalsB) external {
        vm.assume(decimalsA != decimalsB);
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimalsA));

        concrete.decimalsForToken(token);

        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimalsB));

        vm.expectRevert(
            abi.encodeWithSelector(
                ITOFUTokenDecimals.TokenDecimalsReadFailure.selector, token, TOFUOutcome.Inconsistent
            )
        );
        concrete.safeDecimalsForTokenReadOnly(token);
    }

    /// A token returning a value larger than `uint8` from `decimals()` reverts
    /// with `ReadFailure` via the `gt(readDecimals, 0xff)` guard.
    function testSafeDecimalsForTokenReadOnlyOverwideDecimalsReverts(uint256 decimals) external {
        vm.assume(decimals > 0xff);
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));

        vm.expectRevert(
            abi.encodeWithSelector(ITOFUTokenDecimals.TokenDecimalsReadFailure.selector, token, TOFUOutcome.ReadFailure)
        );
        concrete.safeDecimalsForTokenReadOnly(token);
    }

    /// A contract with code but no `decimals()` function (STOP opcode only)
    /// reverts with `ReadFailure` via the `returndatasize < 0x20` guard.
    function testSafeDecimalsForTokenReadOnlyNoDecimalsFunctionReverts() external {
        address token = makeAddr("token");
        vm.etch(token, hex"00");

        vm.expectRevert(
            abi.encodeWithSelector(ITOFUTokenDecimals.TokenDecimalsReadFailure.selector, token, TOFUOutcome.ReadFailure)
        );
        concrete.safeDecimalsForTokenReadOnly(token);
    }

    /// A reverting token after initialization still reverts with
    /// `TokenDecimalsReadFailure` and the `ReadFailure` outcome.
    function testSafeDecimalsForTokenReadOnlyReadFailureInitializedReverts(uint8 decimals) external {
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));

        concrete.decimalsForToken(token);

        vm.mockCallRevert(token, abi.encodeWithSelector(IERC20.decimals.selector), "");

        vm.expectRevert(
            abi.encodeWithSelector(ITOFUTokenDecimals.TokenDecimalsReadFailure.selector, token, TOFUOutcome.ReadFailure)
        );
        concrete.safeDecimalsForTokenReadOnly(token);
    }

    /// A reverting token causes `TokenDecimalsReadFailure` with the
    /// `ReadFailure` outcome.
    function testSafeDecimalsForTokenReadOnlyReadFailureReverts() external {
        address token = makeAddr("token");
        vm.mockCallRevert(token, abi.encodeWithSelector(IERC20.decimals.selector), "");

        vm.expectRevert(
            abi.encodeWithSelector(ITOFUTokenDecimals.TokenDecimalsReadFailure.selector, token, TOFUOutcome.ReadFailure)
        );
        concrete.safeDecimalsForTokenReadOnly(token);
    }

    /// Successive calls on an uninitialized token all succeed, each
    /// independently returning the freshly read decimals.
    function testSafeDecimalsForTokenReadOnlyMultiCallUninitialized(uint8 decimals) external {
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));

        assertEq(concrete.safeDecimalsForTokenReadOnly(token), decimals);
        assertEq(concrete.safeDecimalsForTokenReadOnly(token), decimals);
        assertEq(concrete.safeDecimalsForTokenReadOnly(token), decimals);
    }

    /// Calling `safeDecimalsForTokenReadOnly` does not persist state; a
    /// subsequent stateful call still sees `Initial`.
    function testSafeDecimalsForTokenReadOnlyDoesNotWriteStorage(uint8 decimals) external {
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));

        concrete.safeDecimalsForTokenReadOnly(token);

        (TOFUOutcome outcome,) = concrete.decimalsForToken(token);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Initial));
    }
}
