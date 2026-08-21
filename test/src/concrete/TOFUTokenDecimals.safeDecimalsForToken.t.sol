// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {TOFUTokenDecimals} from "src/concrete/TOFUTokenDecimals.sol";
import {TOFUOutcome, ITOFUTokenDecimals} from "rain-tofu-erc20-decimals-0.1.3/src/interface/ITOFUTokenDecimals.sol";
import {IERC20} from "forge-std-1.16.2/src/interfaces/IERC20.sol";

/// Smoke test for the TOFUTokenDecimals concrete contract's
/// safeDecimalsForToken. Verifies the pass-through wiring to
/// LibTOFUTokenDecimalsImplementation without a fork.
contract TOFUTokenDecimalsSafeDecimalsForTokenTest is Test {
    TOFUTokenDecimals internal concrete;

    function setUp() external {
        concrete = new TOFUTokenDecimals();
    }

    /// Calling with `address(0)` reverts with `TokenDecimalsReadFailure`.
    function testSafeDecimalsForTokenAddressZeroReverts() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                ITOFUTokenDecimals.TokenDecimalsReadFailure.selector, address(0), TOFUOutcome.ReadFailure
            )
        );
        concrete.safeDecimalsForToken(address(0));
    }

    /// First call for an uninitialized token succeeds and returns the freshly
    /// read decimals.
    function testSafeDecimalsForToken(uint8 decimals) external {
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));

        uint8 result = concrete.safeDecimalsForToken(token);
        assertEq(result, decimals);
    }

    /// Explicit boundary test for `decimals=0`. Proves the `initialized`
    /// flag distinguishes stored zero from uninitialized storage: first call
    /// succeeds (`Initial`), second call succeeds (`Consistent`).
    function testSafeDecimalsForTokenDecimalsZero() external {
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(uint8(0)));

        uint8 result = concrete.safeDecimalsForToken(token);
        assertEq(result, 0);

        result = concrete.safeDecimalsForToken(token);
        assertEq(result, 0);
    }

    /// Second call with matching decimals succeeds (`Consistent` path).
    function testSafeDecimalsForTokenConsistent(uint8 decimals) external {
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));

        concrete.safeDecimalsForToken(token);

        uint8 result = concrete.safeDecimalsForToken(token);
        assertEq(result, decimals);
    }

    /// Second call with different decimals reverts with
    /// `TokenDecimalsReadFailure` and the `Inconsistent` outcome.
    function testSafeDecimalsForTokenInconsistentReverts(uint8 decimalsA, uint8 decimalsB) external {
        vm.assume(decimalsA != decimalsB);
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimalsA));

        concrete.safeDecimalsForToken(token);

        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimalsB));

        vm.expectRevert(
            abi.encodeWithSelector(
                ITOFUTokenDecimals.TokenDecimalsReadFailure.selector, token, TOFUOutcome.Inconsistent
            )
        );
        concrete.safeDecimalsForToken(token);
    }

    /// A reverting token causes `TokenDecimalsReadFailure` with the
    /// `ReadFailure` outcome.
    function testSafeDecimalsForTokenReadFailureReverts() external {
        address token = makeAddr("token");
        vm.mockCallRevert(token, abi.encodeWithSelector(IERC20.decimals.selector), "");

        vm.expectRevert(
            abi.encodeWithSelector(ITOFUTokenDecimals.TokenDecimalsReadFailure.selector, token, TOFUOutcome.ReadFailure)
        );
        concrete.safeDecimalsForToken(token);
    }

    /// A token returning a value larger than `uint8` from `decimals()` reverts
    /// with `ReadFailure` via the `gt(readDecimals, 0xff)` guard.
    function testSafeDecimalsForTokenOverwideDecimalsReverts(uint256 decimals) external {
        vm.assume(decimals > 0xff);
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));

        vm.expectRevert(
            abi.encodeWithSelector(ITOFUTokenDecimals.TokenDecimalsReadFailure.selector, token, TOFUOutcome.ReadFailure)
        );
        concrete.safeDecimalsForToken(token);
    }

    /// A contract with code but no `decimals()` function (STOP opcode only)
    /// reverts with `ReadFailure` via the `returndatasize < 0x20` guard.
    function testSafeDecimalsForTokenNoDecimalsFunctionReverts() external {
        address token = makeAddr("token");
        vm.etch(token, hex"00");

        vm.expectRevert(
            abi.encodeWithSelector(ITOFUTokenDecimals.TokenDecimalsReadFailure.selector, token, TOFUOutcome.ReadFailure)
        );
        concrete.safeDecimalsForToken(token);
    }

    /// A reverting token after initialization still causes
    /// `TokenDecimalsReadFailure` with the `ReadFailure` outcome.
    function testSafeDecimalsForTokenReadFailureInitializedReverts(uint8 decimals) external {
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));

        concrete.safeDecimalsForToken(token);

        vm.mockCallRevert(token, abi.encodeWithSelector(IERC20.decimals.selector), "");

        vm.expectRevert(
            abi.encodeWithSelector(ITOFUTokenDecimals.TokenDecimalsReadFailure.selector, token, TOFUOutcome.ReadFailure)
        );
        concrete.safeDecimalsForToken(token);
    }
}
