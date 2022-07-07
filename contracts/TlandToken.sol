// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC1363Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC1363SpenderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC1363ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

/**
 * @title TlandToken
 * @dev ERC20 compatible token.
 */
contract TlandToken is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, ERC20PermitUpgradeable,
ERC20VotesUpgradeable, OwnableUpgradeable, UUPSUpgradeable, IERC1363Upgradeable, ERC165Upgradeable {
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;

    uint256 public buyFee;
    uint256 public sellFee;
    address public feeWallet;
    mapping(address => bool) public isPair;
    mapping(address => bool) public isExcludedFromFee;

    function initialize() public initializer {
        __ERC20_init("Tland Token", "TLAND");
        __ERC20Burnable_init();
        __ERC20Permit_init("Tland Token");
        __Ownable_init();
        __UUPSUpgradeable_init();

        // Set default parameters
        buyFee = 5;
        sellFee = 5;
        feeWallet = owner();

        // Exclude owner and this contract from fee
        isExcludedFromFee[owner()] = true;
        isExcludedFromFee[address(this)] = true;

        _mint(msg.sender, 100_000_000 * 10 ** decimals());
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable, IERC165Upgradeable) returns (bool) {
        return interfaceId == type(IERC1363Upgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    function transferAndCall(address to, uint256 amount) public virtual override returns (bool) {
        return transferAndCall(to, amount, "");
    }

    function transferAndCall(
        address to,
        uint256 amount,
        bytes memory data
    ) public virtual override returns (bool) {
        transfer(to, amount);
        require(_checkAndCallTransfer(_msgSender(), to, amount, data), "ERC1363: _checkAndCallTransfer reverts");
        return true;
    }

    function transferFromAndCall(
        address from,
        address to,
        uint256 amount,
        bytes memory data
    ) public virtual override returns (bool) {
        transferFrom(from, to, amount);
        require(_checkAndCallTransfer(from, to, amount, data), "ERC1363: _checkAndCallTransfer reverts");
        return true;
    }

    function transferFromAndCall(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        return transferFromAndCall(from, to, amount, "");
    }

    function approveAndCall(address spender, uint256 amount) public virtual override returns (bool) {
        return approveAndCall(spender, amount, "");
    }

    function approveAndCall(
        address spender,
        uint256 amount,
        bytes memory data
    ) public virtual override returns (bool) {
        approve(spender, amount);
        require(_checkAndCallApprove(spender, amount, data), "ERC1363: _checkAndCallApprove reverts");
        return true;
    }

    function _checkAndCallTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bytes memory data
    ) internal virtual returns (bool) {
        if (!recipient.isContract()) {
            return false;
        }
        bytes4 retval = IERC1363ReceiverUpgradeable(recipient).onTransferReceived(_msgSender(), sender, amount, data);
        return (retval == IERC1363ReceiverUpgradeable(recipient).onTransferReceived.selector);
    }

    function _checkAndCallApprove(
        address spender,
        uint256 amount,
        bytes memory data
    ) internal virtual returns (bool) {
        if (!spender.isContract()) {
            return false;
        }
        bytes4 retval = IERC1363SpenderUpgradeable(spender).onApprovalReceived(_msgSender(), amount, data);
        return (retval == IERC1363SpenderUpgradeable(spender).onApprovalReceived.selector);
    }

    function addPair(address pair) external onlyOwner {
        isPair[pair] = true;
    }

    function removePair(address pair) external onlyOwner {
        isPair[pair] = false;
    }

    function setFeeWallet(address feeWalletAddress) external onlyOwner {
        feeWallet = feeWalletAddress;
    }

    function setBuyFee(uint256 fee) external onlyOwner {
        require(fee <= 10, "buy fee should be in 0 - 10");
        buyFee = fee;
    }

    function setSellFee(uint256 fee) external onlyOwner {
        require(fee <= 10, "sell fee should be in 0 - 10");
        sellFee = fee;
    }

    function setExcludeFromFee(address account, bool excluded) external onlyOwner {
        isExcludedFromFee[account] = excluded;
    }

    function _authorizeUpgrade(address newImplementation)
    internal
    onlyOwner
    override
    {}

    // Based on https://github.com/OpenZeppelin/openzeppelin-contracts/issues/3093#issuecomment-1008329227
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        // Calculate fee only on swaps
        if (_isSwap(from, to) && !isExcludedFromFee[from] && !isExcludedFromFee[to]) {
            uint256 fee = _calculateFee(to, amount);
            super._transfer(from, feeWallet, fee);
            amount -= fee;
        }

        super._transfer(from, to, amount);
    }

    function _isSwap(address from, address to) private view returns (bool) {
        return isPair[from] || isPair[to];
    }

    function _isSelling(address recipient) private view returns (bool) {
        return isPair[recipient];
    }

    function _calculateFee(address to, uint256 amount) private view returns (uint256) {
        uint256 percentFee = _isSelling(to) ? sellFee : buyFee;
        return amount.mul(percentFee).div(100);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
    internal
    override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._afterTokenTransfer(from, to, amount);
        // Track votes only for non contract addresses
        if(to != address(0) && !to.isContract() && delegates(to) == address(0)) {
            _delegate(to, to);
        }
    }

    function _mint(address to, uint256 amount)
    internal
    override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
    internal
    override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._burn(account, amount);
    }
}
