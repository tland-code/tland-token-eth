// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../ICO.sol";

contract ICOMock is ICO {
    constructor(
        address walletAddress,
        address authorizerAddress,
        uint256 capValue,
        uint256 openingTimeValue,
        uint256 closingTimeValue,
        uint256 tokenPriceValue,
        address[] memory acceptedPaymentTokensValue
    ) ICO (
        walletAddress,
        authorizerAddress,
        capValue,
        openingTimeValue,
        closingTimeValue,
        tokenPriceValue,
        acceptedPaymentTokensValue
    ) {}

    function getChainId() external view returns (uint256) {
        return block.chainid;
    }
}