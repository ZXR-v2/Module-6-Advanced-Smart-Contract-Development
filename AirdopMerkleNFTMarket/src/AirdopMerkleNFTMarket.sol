// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title AirdopMerkleNFTMarket
 * @notice NFT Marketplace with Merkle tree whitelist verification and permit-based purchases
 * @dev Supports multicall for batch operations using delegatecall
 */
contract AirdopMerkleNFTMarket is ReentrancyGuard {
    // ============ Structs ============
    struct Listing {
        address seller;
        uint256 price;
        bool isActive;
    }

    // ============ State Variables ============
    IERC20 public immutable paymentToken;
    IERC721 public immutable nft;
    bytes32 public merkleRoot;
    address public owner;

    // NFT tokenId => Listing
    mapping(uint256 => Listing) public listings;
    
    // Track claimed NFTs per user to prevent double claims
    mapping(address => mapping(uint256 => bool)) public hasClaimed;

    // ============ Constants ============
    uint256 public constant WHITELIST_DISCOUNT = 50; // 50% discount

    // ============ Events ============
    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTDelisted(uint256 indexed tokenId);
    event NFTSold(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price, bool discounted);
    event MerkleRootUpdated(bytes32 oldRoot, bytes32 newRoot);
    event PermitPrePayExecuted(address indexed user, uint256 amount);

    // ============ Errors ============
    error NotOwner();
    error NotSeller();
    error InvalidPrice();
    error NFTNotListed();
    error NFTAlreadyListed();
    error InsufficientAllowance();
    error InvalidMerkleProof();
    error AlreadyClaimed();
    error TransferFailed();
    error InvalidAddress();
    error MulticallFailed(uint256 index, bytes reason);

    // ============ Modifiers ============
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    // ============ Constructor ============
    constructor(
        address _paymentToken,
        address _nft,
        bytes32 _merkleRoot
    ) {
        if (_paymentToken == address(0) || _nft == address(0)) revert InvalidAddress();
        
        paymentToken = IERC20(_paymentToken);
        nft = IERC721(_nft);
        merkleRoot = _merkleRoot;
        owner = msg.sender;
    }

    // ============ Admin Functions ============

    /**
     * @notice Update the Merkle root for whitelist verification
     * @param _newRoot New Merkle root
     */
    function setMerkleRoot(bytes32 _newRoot) external onlyOwner {
        bytes32 oldRoot = merkleRoot;
        merkleRoot = _newRoot;
        emit MerkleRootUpdated(oldRoot, _newRoot);
    }

    /**
     * @notice Transfer ownership of the contract
     * @param newOwner Address of the new owner
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidAddress();
        owner = newOwner;
    }

    // ============ Listing Functions ============

    /**
     * @notice List an NFT for sale
     * @param tokenId ID of the NFT to list
     * @param price Price in payment tokens
     */
    function list(uint256 tokenId, uint256 price) external {
        if (price == 0) revert InvalidPrice();
        if (listings[tokenId].isActive) revert NFTAlreadyListed();
        
        // Verify ownership and approval
        address tokenOwner = nft.ownerOf(tokenId);
        require(
            tokenOwner == msg.sender || 
            nft.isApprovedForAll(tokenOwner, msg.sender) ||
            nft.getApproved(tokenId) == msg.sender,
            "Not authorized to list"
        );

        // Transfer NFT to marketplace (escrow)
        nft.transferFrom(tokenOwner, address(this), tokenId);

        listings[tokenId] = Listing({
            seller: msg.sender,
            price: price,
            isActive: true
        });

        emit NFTListed(tokenId, msg.sender, price);
    }

    /**
     * @notice Delist an NFT from the marketplace
     * @param tokenId ID of the NFT to delist
     */
    function delist(uint256 tokenId) external {
        Listing storage listing = listings[tokenId];
        if (!listing.isActive) revert NFTNotListed();
        if (listing.seller != msg.sender) revert NotSeller();

        listing.isActive = false;
        
        // Return NFT to seller
        nft.transferFrom(address(this), msg.sender, tokenId);

        emit NFTDelisted(tokenId);
    }

    // ============ Purchase Functions ============

    /**
     * @notice Regular purchase (no discount)
     * @param tokenId ID of the NFT to purchase
     */
    function buy(uint256 tokenId) external nonReentrant {
        Listing storage listing = listings[tokenId];
        if (!listing.isActive) revert NFTNotListed();

        uint256 price = listing.price;
        address seller = listing.seller;

        listing.isActive = false;

        // Transfer payment from buyer to seller
        bool success = paymentToken.transferFrom(msg.sender, seller, price);
        if (!success) revert TransferFailed();

        // Transfer NFT to buyer
        nft.transferFrom(address(this), msg.sender, tokenId);

        emit NFTSold(tokenId, msg.sender, seller, price, false);
    }

    // ============ Multicall Functions ============

    /**
     * @notice Execute permit for pre-authorization of token transfer
     * @dev This function should be called as part of multicall before claimNFT
     * @param tokenOwner Token owner address
     * @param spender Spender address (this contract)
     * @param value Amount to approve
     * @param deadline Permit deadline
     * @param v Signature v
     * @param r Signature r
     * @param s Signature s
     */
    function permitPrePay(
        address tokenOwner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // Call permit on the token contract
        IERC20Permit(address(paymentToken)).permit(tokenOwner, spender, value, deadline, v, r, s);

        emit PermitPrePayExecuted(tokenOwner, value);
    }

    /**
     * @notice Claim NFT with whitelist discount using Merkle proof
     * @dev Requires prior permitPrePay call via multicall
     * @param tokenId ID of the NFT to claim
     * @param merkleProof Merkle proof for whitelist verification
     */
    function claimNFT(
        uint256 tokenId,
        bytes32[] calldata merkleProof
    ) external nonReentrant {
        // Verify listing is active
        Listing storage listing = listings[tokenId];
        if (!listing.isActive) revert NFTNotListed();

        // Verify whitelist using Merkle proof
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender))));
        if (!MerkleProof.verify(merkleProof, merkleRoot, leaf)) {
            revert InvalidMerkleProof();
        }

        // Check if already claimed this specific NFT
        if (hasClaimed[msg.sender][tokenId]) revert AlreadyClaimed();
        hasClaimed[msg.sender][tokenId] = true;

        // Calculate discounted price (50% off)
        uint256 fullPrice = listing.price;
        uint256 discountedPrice = (fullPrice * (100 - WHITELIST_DISCOUNT)) / 100;
        
        address seller = listing.seller;
        listing.isActive = false;

        // Transfer discounted payment from buyer to seller
        bool success = paymentToken.transferFrom(msg.sender, seller, discountedPrice);
        if (!success) revert TransferFailed();

        // Transfer NFT to buyer
        nft.transferFrom(address(this), msg.sender, tokenId);

        emit NFTSold(tokenId, msg.sender, seller, discountedPrice, true);
    }

    /**
     * @notice Execute multiple calls in a single transaction using delegatecall
     * @param data Array of encoded function calls
     * @return results Array of return data from each call
     */
    function multicall(bytes[] calldata data) external returns (bytes[] memory results) {
        results = new bytes[](data.length);
        
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);
            
            if (!success) {
                // If the call failed, revert with the error message
                if (result.length > 0) {
                    // Bubble up the revert reason
                    assembly {
                        let returndata_size := mload(result)
                        revert(add(32, result), returndata_size)
                    }
                } else {
                    revert MulticallFailed(i, result);
                }
            }
            
            results[i] = result;
        }
    }

    // ============ View Functions ============

    /**
     * @notice Get listing details for an NFT
     * @param tokenId ID of the NFT
     * @return seller Address of the seller
     * @return price Price in payment tokens
     * @return isActive Whether the listing is active
     */
    function getListing(uint256 tokenId) external view returns (
        address seller,
        uint256 price,
        bool isActive
    ) {
        Listing storage listing = listings[tokenId];
        return (listing.seller, listing.price, listing.isActive);
    }

    /**
     * @notice Calculate the discounted price for whitelist users
     * @param tokenId ID of the NFT
     * @return discountedPrice The price after 50% discount
     */
    function getDiscountedPrice(uint256 tokenId) external view returns (uint256 discountedPrice) {
        Listing storage listing = listings[tokenId];
        if (!listing.isActive) revert NFTNotListed();
        return (listing.price * (100 - WHITELIST_DISCOUNT)) / 100;
    }

    /**
     * @notice Verify if an address is in the whitelist
     * @param account Address to verify
     * @param merkleProof Merkle proof for the address
     * @return isWhitelisted Whether the address is whitelisted
     */
    function verifyWhitelist(
        address account,
        bytes32[] calldata merkleProof
    ) external view returns (bool isWhitelisted) {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account))));
        return MerkleProof.verify(merkleProof, merkleRoot, leaf);
    }
}
