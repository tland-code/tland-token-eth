// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "eth-token-recover/contracts/TokenRecover.sol";

error InvalidAddress();
error InvalidPercentValue();
error EndTimeMustBeAfterStartTime();
error CliffTimeMustBeShorterThanVestingTime();
error ChangesLocked();
error BeneficiariesAndBalancesLengthsMustMatch();
error EmptyBalance();
error VestingNotStarted();
error InvalidBeneficiary();
error NothingToWithdraw();

/**
 * @title Vesting
 * @dev Vesting for BEP20 compatible token.
 */
contract Vesting is Ownable, TokenRecover {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    bool private _locked;

    address public token;
    uint256 public endTime;
    uint256 public startTime;
    uint256 public cliffTime;
    uint256 public startPercent;

    mapping(address => uint256) public currentBalances;
    mapping(address => uint256) public initialBalances;

    event TokensReleased(address beneficiary, uint256 amount);

    /**
     * @dev Configures vesting for specified accounts.
     * @param startTimeValue Timestamp after which initial amount of tokens is released.
     * @param endTimeValue Timestamp after which entire amount of tokens is released.
     * @param cliffTimeValue the time when the token release is paused
     * @param startPercentValue Percent of tokens available after initial release.
     * @param tokenAddress address of token released to beneficiaries
     */
    constructor(
        uint256 startTimeValue,
        uint256 endTimeValue,
        uint256 cliffTimeValue,
        uint8 startPercentValue,
        address tokenAddress
    ) {
        if (startPercentValue > 100)
            revert InvalidPercentValue();
        if (endTimeValue <= startTimeValue)
            revert EndTimeMustBeAfterStartTime();
        if (cliffTimeValue > endTimeValue - startTimeValue)
            revert CliffTimeMustBeShorterThanVestingTime();
        if (tokenAddress == address(0))
            revert InvalidAddress();

        endTime = endTimeValue;
        startTime = startTimeValue;
        cliffTime = cliffTimeValue;
        startPercent = startPercentValue;
        token = tokenAddress;
    }

    /**
     * @dev Add beneficiaries
     */
    function addBeneficiaries(address[] memory beneficiaries, uint256[] memory balances) public onlyOwner {
        if (beneficiaries.length != balances.length)
            revert BeneficiariesAndBalancesLengthsMustMatch();
        if (isLocked())
            revert ChangesLocked();

        for (uint256 i = 0; i < beneficiaries.length; ++i) {
            currentBalances[beneficiaries[i]] = balances[i];
            initialBalances[beneficiaries[i]] = balances[i];
        }
    }

    /**
     * @dev Lock the contract
     */
    function lock() public onlyOwner {
        _locked = true;
    }

    /**
     * @dev Sends all released tokens (if any) to the caller.
     */
    function release() public {
        if (block.timestamp < startTime)
            revert VestingNotStarted();
        if (initialBalances[msg.sender] == 0)
            revert InvalidBeneficiary();
        if (initialBalances[msg.sender] == 0)
            revert NothingToWithdraw();

        uint256 amount = withdrawalLimit(msg.sender);

        if (amount == 0)
            revert NothingToWithdraw();

        currentBalances[msg.sender] = currentBalances[msg.sender].sub(amount);

        IERC20(token).safeTransfer(msg.sender, amount);

        emit TokensReleased(msg.sender, amount);
    }

    /**
     * @dev Sets token address.
     */
    function setToken(address tokenAddress) public onlyOwner {
        if (isLocked())
            revert ChangesLocked();
        if (tokenAddress == address(0))
            revert InvalidAddress();
        token = tokenAddress;
    }

    /**
     * @dev Sets start time.
     */
    function setStartTime(uint256 value) public onlyOwner {
        if (isLocked())
            revert ChangesLocked();
        if (endTime <= startTime)
            revert EndTimeMustBeAfterStartTime();
        startTime = value;
    }

    /**
     * @dev Sets end time.
     */
    function setEndTime(uint256 value) public onlyOwner {
        if (isLocked())
            revert ChangesLocked();
        if (endTime <= startTime)
            revert EndTimeMustBeAfterStartTime();
        endTime = value;
    }

    /**
     * @dev Sets cliff time.
     */
    function setCliffTime(uint256 value) public onlyOwner {
        if (isLocked())
            revert ChangesLocked();
        if (value > endTime - startTime)
            revert CliffTimeMustBeShorterThanVestingTime();
        cliffTime = value;
    }

    /**
     * @dev Sets start percentage.
     */
    function setStartPercent(uint256 value) public onlyOwner {
        if (isLocked())
            revert ChangesLocked();
        if (value > 100)
            revert InvalidPercentValue();
        startPercent = value;
    }

    /**
     * @dev Check if contract is locked
     */
    function isLocked() public view returns (bool) {
        return _locked;
    }

    /**
     * @dev Returns total withdrawn for given address.
     * @param beneficiary Address to check.
     */
    function totalWithdrawn(address beneficiary) public view returns (uint256) {
        return (initialBalances[beneficiary].sub(currentBalances[beneficiary]));
    }

    /**
     * @dev Returns withdrawal limit for given address.
     * @param beneficiary Address to check.
     */
    function withdrawalLimit(address beneficiary) public view returns (uint256) {
        return (_amountAllowedToWithdraw(initialBalances[beneficiary]).sub(totalWithdrawn(beneficiary)));
    }

    /**
     * @dev Returns amount allowed to withdraw for given initial initialBalanceValue.
     * @param initialBalanceValue Initial initialBalanceValue.
     */
    function _amountAllowedToWithdraw(uint256 initialBalanceValue) internal view returns (uint256) {
        if (initialBalanceValue == 0 || block.timestamp < startTime) {
            return 0;
        }

        if (block.timestamp >= endTime) {
            return initialBalanceValue;
        }

        if (block.timestamp < startTime + cliffTime) {
            return startPercent.mul(initialBalanceValue).div(100);
        }

        uint256 curTimeDiff = block.timestamp.sub(startTime + cliffTime);
        uint256 maxTimeDiff = endTime.sub(startTime + cliffTime);

        uint256 beginPromile = startPercent.mul(10);
        uint256 otherPromile = curTimeDiff.mul(uint256(1000).sub(beginPromile)).div(maxTimeDiff);
        uint256 promile = beginPromile.add(otherPromile);

        if (promile >= 1000) {
            return initialBalanceValue;
        }

        return promile.mul(initialBalanceValue).div(1000);
    }
}
