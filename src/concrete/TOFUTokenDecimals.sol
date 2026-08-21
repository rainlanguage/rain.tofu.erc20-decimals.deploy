// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    ITOFUTokenDecimals,
    TOFUTokenDecimalsResult,
    TOFUOutcome
} from "rain-tofu-erc20-decimals-0.1.3/src/interface/ITOFUTokenDecimals.sol";
import {
    LibTOFUTokenDecimalsImplementation
} from "rain-tofu-erc20-decimals-0.1.3/src/lib/LibTOFUTokenDecimalsImplementation.sol";

/// @title TOFUTokenDecimals
/// @notice Minimal implementation of the ITOFUTokenDecimals interface using
/// LibTOFUTokenDecimalsImplementation for the logic. The concrete contract
/// simply stores the mapping of token addresses to TOFUTokenDecimalsResult
/// structs and delegates all logic to the library.
contract TOFUTokenDecimals is ITOFUTokenDecimals {
    /// @notice Storage mapping from token address to its TOFU decimals result.
    // forge-lint: disable-next-line(mixed-case-variable)
    mapping(address token => TOFUTokenDecimalsResult tofuTokenDecimals) internal sTOFUTokenDecimals;

    /// @inheritdoc ITOFUTokenDecimals
    function decimalsForTokenReadOnly(address token) external view returns (TOFUOutcome, uint8) {
        // slither-disable-next-line unused-return
        return LibTOFUTokenDecimalsImplementation.decimalsForTokenReadOnly(sTOFUTokenDecimals, token);
    }

    /// @inheritdoc ITOFUTokenDecimals
    function decimalsForToken(address token) external returns (TOFUOutcome, uint8) {
        // slither-disable-next-line unused-return
        return LibTOFUTokenDecimalsImplementation.decimalsForToken(sTOFUTokenDecimals, token);
    }

    /// @inheritdoc ITOFUTokenDecimals
    function safeDecimalsForToken(address token) external returns (uint8) {
        return LibTOFUTokenDecimalsImplementation.safeDecimalsForToken(sTOFUTokenDecimals, token);
    }

    /// @inheritdoc ITOFUTokenDecimals
    function safeDecimalsForTokenReadOnly(address token) external view returns (uint8) {
        return LibTOFUTokenDecimalsImplementation.safeDecimalsForTokenReadOnly(sTOFUTokenDecimals, token);
    }
}
