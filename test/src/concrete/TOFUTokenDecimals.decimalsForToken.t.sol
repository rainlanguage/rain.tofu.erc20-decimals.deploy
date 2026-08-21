// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {TOFUTokenDecimals} from "src/concrete/TOFUTokenDecimals.sol";
import {TOFUOutcome} from "rain-tofu-erc20-decimals-0.1.3/src/interface/ITOFUTokenDecimals.sol";
import {IERC20} from "forge-std-1.16.2/src/interfaces/IERC20.sol";

/// Smoke test for the TOFUTokenDecimals concrete contract's decimalsForToken.
/// Verifies the pass-through wiring to LibTOFUTokenDecimalsImplementation
/// without a fork.
contract TOFUTokenDecimalsDecimalsForTokenTest is Test {
    TOFUTokenDecimals internal concrete;

    function setUp() external {
        concrete = new TOFUTokenDecimals();
    }

    /// Calling with `address(0)` produces `ReadFailure` with zero decimals.
    function testDecimalsForTokenAddressZero() external {
        (TOFUOutcome outcome, uint8 result) = concrete.decimalsForToken(address(0));
        assertEq(uint256(outcome), uint256(TOFUOutcome.ReadFailure));
        assertEq(result, 0);
    }

    /// First call for an uninitialized token returns `Initial` with the
    /// freshly read decimals value.
    function testDecimalsForToken(uint8 decimals) external {
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));

        (TOFUOutcome outcome, uint8 result) = concrete.decimalsForToken(token);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Initial));
        assertEq(result, decimals);
    }

    /// Explicit boundary test for `decimals=0`. Proves the `initialized`
    /// flag distinguishes stored zero from uninitialized storage: first call
    /// returns `Initial`, second returns `Consistent`.
    function testDecimalsForTokenDecimalsZero() external {
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(uint8(0)));

        (TOFUOutcome outcome, uint8 result) = concrete.decimalsForToken(token);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Initial));
        assertEq(result, 0);

        (outcome, result) = concrete.decimalsForToken(token);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Consistent));
        assertEq(result, 0);
    }

    /// Second call with the same decimals returns `Consistent` and the
    /// stored value.
    function testDecimalsForTokenConsistent(uint8 decimals) external {
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));

        concrete.decimalsForToken(token);

        (TOFUOutcome outcome, uint8 result) = concrete.decimalsForToken(token);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Consistent));
        assertEq(result, decimals);
    }

    /// Second call with different decimals returns `Inconsistent` and the
    /// originally stored value, not the new one.
    function testDecimalsForTokenInconsistent(uint8 decimalsA, uint8 decimalsB) external {
        vm.assume(decimalsA != decimalsB);
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimalsA));

        concrete.decimalsForToken(token);

        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimalsB));

        (TOFUOutcome outcome, uint8 result) = concrete.decimalsForToken(token);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Inconsistent));
        assertEq(result, decimalsA);
    }

    /// A reverting token produces `ReadFailure` with zero decimals when
    /// uninitialized.
    function testDecimalsForTokenReadFailure() external {
        address token = makeAddr("token");
        vm.mockCallRevert(token, abi.encodeWithSelector(IERC20.decimals.selector), "");

        (TOFUOutcome outcome, uint8 result) = concrete.decimalsForToken(token);
        assertEq(uint256(outcome), uint256(TOFUOutcome.ReadFailure));
        assertEq(result, 0);
    }

    /// A reverting token produces `ReadFailure` but returns the previously
    /// stored decimals when already initialized.
    function testDecimalsForTokenReadFailureInitialized(uint8 decimals) external {
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));
        concrete.decimalsForToken(token);

        vm.mockCallRevert(token, abi.encodeWithSelector(IERC20.decimals.selector), "");

        (TOFUOutcome outcome, uint8 result) = concrete.decimalsForToken(token);
        assertEq(uint256(outcome), uint256(TOFUOutcome.ReadFailure));
        assertEq(result, decimals);
    }

    /// Initializing two different tokens does not cross-contaminate their
    /// stored decimals.
    function testDecimalsForTokenCrossTokenIsolation(uint8 decimalsA, uint8 decimalsB) external {
        address tokenA = makeAddr("tokenA");
        address tokenB = makeAddr("tokenB");
        vm.mockCall(tokenA, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimalsA));
        vm.mockCall(tokenB, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimalsB));

        concrete.decimalsForToken(tokenA);
        concrete.decimalsForToken(tokenB);

        (TOFUOutcome outcomeA, uint8 resultA) = concrete.decimalsForToken(tokenA);
        assertEq(uint256(outcomeA), uint256(TOFUOutcome.Consistent));
        assertEq(resultA, decimalsA);

        (TOFUOutcome outcomeB, uint8 resultB) = concrete.decimalsForToken(tokenB);
        assertEq(uint256(outcomeB), uint256(TOFUOutcome.Consistent));
        assertEq(resultB, decimalsB);
    }

    /// A `ReadFailure` after initialization does not corrupt the stored value;
    /// restoring the token recovers `Consistent`.
    function testDecimalsForTokenStorageImmutableOnReadFailure(uint8 decimals) external {
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));
        concrete.decimalsForToken(token);

        vm.mockCallRevert(token, abi.encodeWithSelector(IERC20.decimals.selector), "");
        concrete.decimalsForToken(token);

        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));

        (TOFUOutcome outcome, uint8 result) = concrete.decimalsForToken(token);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Consistent));
        assertEq(result, decimals);
    }

    /// A ReadFailure on the very first (uninitialized) call must not write
    /// storage. A subsequent valid call should still return Initial, proving
    /// the failed first attempt left storage untouched.
    function testDecimalsForTokenNoStorageWriteOnUninitializedReadFailure(uint8 decimals) external {
        address token = makeAddr("token");

        // First call: ReadFailure via reverting token on uninitialized storage.
        vm.mockCallRevert(token, abi.encodeWithSelector(IERC20.decimals.selector), "");
        (TOFUOutcome outcome, uint8 result) = concrete.decimalsForToken(token);
        assertEq(uint256(outcome), uint256(TOFUOutcome.ReadFailure));
        assertEq(result, 0);

        // Fix mock to return a valid value: should be Initial, not Consistent,
        // proving the ReadFailure did not initialize storage.
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));
        (outcome, result) = concrete.decimalsForToken(token);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Initial));
        assertEq(result, decimals);
    }

    /// A token returning a value larger than `uint8` from `decimals()` is
    /// treated as `ReadFailure` via the `gt(readDecimals, 0xff)` guard.
    function testDecimalsForTokenOverwideDecimals(uint256 decimals) external {
        vm.assume(decimals > 0xff);
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));

        (TOFUOutcome outcome, uint8 result) = concrete.decimalsForToken(token);
        assertEq(uint256(outcome), uint256(TOFUOutcome.ReadFailure));
        assertEq(result, 0);
    }

    /// A contract with code but no `decimals()` function (STOP opcode only)
    /// produces `ReadFailure`. The staticcall succeeds but returns 0 bytes,
    /// exercising the `returndatasize < 0x20` guard.
    function testDecimalsForTokenNoDecimalsFunction() external {
        address token = makeAddr("token");
        vm.etch(token, hex"00");

        (TOFUOutcome outcome, uint8 result) = concrete.decimalsForToken(token);
        assertEq(uint256(outcome), uint256(TOFUOutcome.ReadFailure));
        assertEq(result, 0);
    }

    /// An `Inconsistent` outcome does not overwrite the stored value; the
    /// original decimals remain and can still produce `Consistent`.
    function testDecimalsForTokenStorageImmutableOnInconsistent(uint8 decimalsA, uint8 decimalsB) external {
        vm.assume(decimalsA != decimalsB);
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimalsA));
        concrete.decimalsForToken(token);

        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimalsB));
        concrete.decimalsForToken(token);

        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimalsA));

        (TOFUOutcome outcome, uint8 result) = concrete.decimalsForToken(token);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Consistent));
        assertEq(result, decimalsA);
    }

    /// All four external functions share one storage mapping. Exercises them
    /// in sequence on the same token to verify shared-state wiring through
    /// the concrete contract.
    function testDecimalsForTokenCrossFunctionInteraction(uint8 decimals) external {
        address token = makeAddr("token");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));

        // 1. decimalsForToken: initializes storage.
        (TOFUOutcome outcome, uint8 result) = concrete.decimalsForToken(token);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Initial));
        assertEq(result, decimals);

        // 2. decimalsForTokenReadOnly: sees the stored value as Consistent.
        (outcome, result) = concrete.decimalsForTokenReadOnly(token);
        assertEq(uint256(outcome), uint256(TOFUOutcome.Consistent));
        assertEq(result, decimals);

        // 3. safeDecimalsForToken: succeeds with the stored value.
        assertEq(concrete.safeDecimalsForToken(token), decimals);

        // 4. safeDecimalsForTokenReadOnly: succeeds with the stored value.
        assertEq(concrete.safeDecimalsForTokenReadOnly(token), decimals);
    }
}
