// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title PaymentToken
 * @notice Upgradeable ERC20 token with permit functionality for gasless approvals
 * @dev Used as payment token in the NFT marketplace
 */
contract PaymentToken is 
    Initializable, 
    ERC20Upgradeable, 
    ERC20PermitUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable 
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the payment token
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param initialOwner Address of the initial owner
     */
    function initialize(
        string memory name_,
        string memory symbol_,
        address initialOwner
    ) public initializer {
        __ERC20_init(name_, symbol_);
        __ERC20Permit_init(name_);
        __Ownable_init(initialOwner);
    }

    /**
     * @notice Mint tokens to the specified address
     * @param to Address to receive the tokens
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
