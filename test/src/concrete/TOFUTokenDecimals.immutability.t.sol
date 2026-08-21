// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {TOFUTokenDecimals} from "src/concrete/TOFUTokenDecimals.sol";
import {LibExtrospectBytecode} from "rain-extrospection-0.1.13/src/lib/LibExtrospectBytecode.sol";
import {
    EVM_OP_SELFDESTRUCT,
    EVM_OP_DELEGATECALL,
    EVM_OP_CALLCODE
} from "rain-extrospection-0.1.13/src/lib/EVMOpcodes.sol";

contract TOFUTokenDecimalsImmutabilityTest is Test {
    /// The deployed bytecode of TOFUTokenDecimals MUST NOT contain any
    /// reachable opcodes that could allow the contract to be mutated or
    /// destroyed after deployment.
    function testNoMutableOpcodes() external {
        TOFUTokenDecimals concrete = new TOFUTokenDecimals();
        bytes memory bytecode = address(concrete).code;

        uint256 reachable = LibExtrospectBytecode.scanEVMOpcodesReachableInBytecode(bytecode);

        // SELFDESTRUCT would allow the contract to be destroyed.
        // forge-lint: disable-next-line(incorrect-shift)
        assertEq(reachable & (1 << EVM_OP_SELFDESTRUCT), 0, "SELFDESTRUCT is reachable");
        // DELEGATECALL would allow arbitrary code execution in the contract's
        // storage context.
        // forge-lint: disable-next-line(incorrect-shift)
        assertEq(reachable & (1 << EVM_OP_DELEGATECALL), 0, "DELEGATECALL is reachable");
        // CALLCODE would allow arbitrary code execution in the contract's
        // storage context.
        // forge-lint: disable-next-line(incorrect-shift)
        assertEq(reachable & (1 << EVM_OP_CALLCODE), 0, "CALLCODE is reachable");
    }
}
