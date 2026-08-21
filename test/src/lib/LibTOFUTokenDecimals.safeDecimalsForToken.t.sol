// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {LibRainDeploy} from "rain-deploy-0.1.7/src/lib/LibRainDeploy.sol";
import {LibTOFUTokenDecimals} from "rain-tofu-erc20-decimals-0.1.3/src/lib/LibTOFUTokenDecimals.sol";
import {TOFUTokenDecimals} from "src/concrete/TOFUTokenDecimals.sol";
import {TOFUOutcome} from "rain-tofu-erc20-decimals-0.1.3/src/lib/LibTOFUTokenDecimalsImplementation.sol";
import {ITOFUTokenDecimals} from "rain-tofu-erc20-decimals-0.1.3/src/interface/ITOFUTokenDecimals.sol";
import {IERC20} from "forge-std-1.16.2/src/interfaces/IERC20.sol";

contract LibTOFUTokenDecimalsSafeDecimalsForTokenTest is Test {
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

    function testSafeDecimalsForTokenAddressZero() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                ITOFUTokenDecimals.TokenDecimalsReadFailure.selector, address(0), TOFUOutcome.ReadFailure
            )
        );
        LibTOFUTokenDecimals.safeDecimalsForToken(address(0));
    }

    function testSafeDecimalsForTokenValidValue(uint8 decimals) external {
        address token = makeAddr("TokenA");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));
        assertEq(LibTOFUTokenDecimals.safeDecimalsForToken(token), decimals);
    }

    function testSafeDecimalsForTokenConsistentInconsistent(uint8 decimalsA, uint8 decimalsB) external {
        address token = makeAddr("TokenA");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimalsA));

        // First call initializes.
        assertEq(LibTOFUTokenDecimals.safeDecimalsForToken(token), decimalsA);

        // Second call with potentially different value.
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimalsB));
        if (decimalsA == decimalsB) {
            assertEq(LibTOFUTokenDecimals.safeDecimalsForToken(token), decimalsA);
        } else {
            vm.expectRevert(
                abi.encodeWithSelector(
                    ITOFUTokenDecimals.TokenDecimalsReadFailure.selector, token, TOFUOutcome.Inconsistent
                )
            );
            LibTOFUTokenDecimals.safeDecimalsForToken(token);
        }
    }

    /// When storage is already initialized and a subsequent read returns a
    /// value too large for uint8, safeDecimalsForToken must revert with
    /// ReadFailure.
    function testSafeDecimalsForTokenInvalidValueTooLargeInitialized(uint8 storedDecimals, uint256 decimals) external {
        vm.assume(decimals > 0xff);
        address token = makeAddr("TokenB");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(storedDecimals));
        LibTOFUTokenDecimals.safeDecimalsForToken(token);

        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));
        vm.expectRevert(
            abi.encodeWithSelector(ITOFUTokenDecimals.TokenDecimalsReadFailure.selector, token, TOFUOutcome.ReadFailure)
        );
        LibTOFUTokenDecimals.safeDecimalsForToken(token);
    }

    function testSafeDecimalsForTokenInvalidValueTooLarge(uint256 decimals) external {
        vm.assume(decimals > 0xff);
        address token = makeAddr("TokenB");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(decimals));
        vm.expectRevert(
            abi.encodeWithSelector(ITOFUTokenDecimals.TokenDecimalsReadFailure.selector, token, TOFUOutcome.ReadFailure)
        );
        LibTOFUTokenDecimals.safeDecimalsForToken(token);
    }

    /// When storage is already initialized and a subsequent read returns
    /// insufficient data, safeDecimalsForToken must revert with ReadFailure.
    function testSafeDecimalsForTokenInvalidValueNotEnoughDataInitialized(
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
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(storedDecimals));
        LibTOFUTokenDecimals.safeDecimalsForToken(token);

        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), data);
        vm.expectRevert(
            abi.encodeWithSelector(ITOFUTokenDecimals.TokenDecimalsReadFailure.selector, token, TOFUOutcome.ReadFailure)
        );
        LibTOFUTokenDecimals.safeDecimalsForToken(token);
    }

    function testSafeDecimalsForTokenInvalidValueNotEnoughData(bytes memory data, uint256 length) external {
        length = bound(length, 0, 0x1f);
        if (data.length > length) {
            assembly ("memory-safe") {
                mstore(data, length)
            }
        }
        address token = makeAddr("TokenC");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), data);
        vm.expectRevert(
            abi.encodeWithSelector(ITOFUTokenDecimals.TokenDecimalsReadFailure.selector, token, TOFUOutcome.ReadFailure)
        );
        LibTOFUTokenDecimals.safeDecimalsForToken(token);
    }

    /// When storage is already initialized and the token contract starts
    /// reverting, safeDecimalsForToken must revert with ReadFailure.
    function testSafeDecimalsForTokenContractRevertInitialized(uint8 storedDecimals) external {
        address token = makeAddr("TokenD");
        vm.mockCall(token, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(storedDecimals));
        LibTOFUTokenDecimals.safeDecimalsForToken(token);

        vm.clearMockedCalls();
        vm.etch(token, hex"fd");
        vm.expectRevert(
            abi.encodeWithSelector(ITOFUTokenDecimals.TokenDecimalsReadFailure.selector, token, TOFUOutcome.ReadFailure)
        );
        LibTOFUTokenDecimals.safeDecimalsForToken(token);
    }

    function testSafeDecimalsForTokenContractRevert() external {
        address token = makeAddr("TokenD");
        vm.etch(token, hex"fd");
        vm.expectRevert(
            abi.encodeWithSelector(ITOFUTokenDecimals.TokenDecimalsReadFailure.selector, token, TOFUOutcome.ReadFailure)
        );
        LibTOFUTokenDecimals.safeDecimalsForToken(token);
    }
}
