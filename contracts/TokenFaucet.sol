// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Context.sol";
import "./TlandTokenMintable.sol";

error TokensAlreadyClaimed();
error InvalidAmountToClaim();
error InvalidAddress();

contract TokenFaucet is Context {

    address public token;
    uint256 public amountToClaim;
    mapping(address => bool) private _wasClaimed;

    constructor(
        address tokenAddress,
        uint256 amountToClaimValue
    ) {
        if (tokenAddress == address(0))
            revert InvalidAddress();
        if (amountToClaimValue == 0)
            revert InvalidAmountToClaim();

        token = tokenAddress;
        amountToClaim = amountToClaimValue;
    }

    function claim() public {
        if (_wasClaimed[_msgSender()]) {
            revert TokensAlreadyClaimed();
        }

        _wasClaimed[_msgSender()] = true;

        TlandTokenMintable(token).mint(_msgSender(), amountToClaim);
    }

    function wasClaimed() public view returns (bool) {
        return _wasClaimed[_msgSender()];
    }
}
