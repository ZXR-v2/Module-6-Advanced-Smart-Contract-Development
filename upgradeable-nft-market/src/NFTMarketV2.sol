// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// ============================================================================
// 📚 V2 升级说明
// ============================================================================
//
// NFTMarketV2 继承自 NFTMarketV1，这是可升级合约的标准做法：
// - 保持存储布局兼容（V1 的变量位置不变）
// - 在 V1 的基础上添加新功能
// - V1 的所有功能自动继承，无需重复实现
//
// ❓ 为什么要继承而不是重新写？
//    - 存储布局必须兼容，继承自动保证了这一点
//    - 代码复用，减少重复
//    - V1 的所有功能（list, buy, delist 等）自动可用
//
import "./NFTMarketV1.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title NFTMarketV2
 * @notice Upgradeable NFT Marketplace - Version 2
 * @dev Adds signature-based listing functionality
 * 
 * ============================================================================
 * 📐 V2 存储布局（继承自 V1）
 * ============================================================================
 * 
 *   来自 V1：
 *   ┌─────────────────────────────────────────┐
 *   │ Slot 0:  paymentToken                   │
 *   │ Slot 1:  nft                            │
 *   │ Slot 2:  listings mapping               │
 *   │ Slot 3:  totalListings                  │
 *   │ Slot 4:  feePercent                     │
 *   │ Slot 5:  accumulatedFees                │
 *   │ Slot 6:  _status (reentrancy guard)     │
 *   │ Slot 7-49: __gap (V1 预留)              │
 *   ├─────────────────────────────────────────┤
 *   │ 来自 V2（新增）：                         │
 *   │ Slot 50: nonces mapping                 │ ← V2 新变量从这里开始
 *   │ Slot 51: usedSignatures mapping         │
 *   │ Slot 52-98: __gap_v2 (V2 预留)          │
 *   └─────────────────────────────────────────┘
 * 
 *   📝 注意：V2 的变量紧跟在 V1 的 __gap 之后
 *           这就是为什么 V1 需要 __gap 的原因！
 * 
 * ============================================================================
 * 🆕 V2 新增功能：离线签名上架
 * ============================================================================
 * 
 *   传统上架流程：
 *   ┌─────────────┐    ┌─────────────┐
 *   │ 卖家调用     │ →  │ 链上交易     │  ← 每次上架都要付 gas
 *   │ list()      │    │ (消耗gas)   │
 *   └─────────────┘    └─────────────┘
 * 
 *   签名上架流程：
 *   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
 *   │ 卖家签名     │ →  │ 链下传递     │ →  │ 买家/任何人  │
 *   │ (免费)      │    │ (免费)      │    │ 提交上架     │
 *   └─────────────┘    └─────────────┘    └─────────────┘
 * 
 *   优势：
 *   - 卖家只需一次 setApprovalForAll（一次性 gas）
 *   - 之后每次上架只需签名（完全免费）
 *   - 甚至可以让买家直接用签名购买（buyWithSignature）
 * 
 */
contract NFTMarketV2 is NFTMarketV1, EIP712Upgradeable {
    using ECDSA for bytes32;

    // ============ Constants ============
    bytes32 public constant LISTING_TYPEHASH = keccak256(
        "Listing(uint256 tokenId,uint256 price,uint256 nonce,uint256 deadline)"
    );

    // ============================================================================
    // 📦 V2 新增的状态变量
    // ============================================================================
    //
    // 这些变量的存储位置在 V1 的 __gap 之后
    // 所以即使 V1 将来添加新变量（占用 __gap 的空间），也不会影响 V2
    //
    
    /// @notice Mapping of user => nonce for signature replay protection
    /// @dev nonce 用于防止签名重放攻击，每次使用签名后 nonce 自增
    mapping(address => uint256) public nonces;    // Slot 50
    
    /// @notice Mapping of signature hash => used status
    /// @dev 记录已使用的签名，防止同一签名被重复使用
    mapping(bytes32 => bool) public usedSignatures;  // Slot 51

    // ============ Events ============
    event NFTListedWithSignature(
        uint256 indexed tokenId, 
        address indexed seller, 
        uint256 price,
        bytes32 signatureHash
    );
    event SignatureCancelled(address indexed seller, bytes32 signatureHash);

    // ============ Errors ============
    error InvalidSignature();
    error SignatureExpired();
    error SignatureAlreadyUsed();
    error NotTokenOwner();

    // ============================================================================
    // 📦 V2 的 Storage Gap
    // ============================================================================
    //
    // V2 也预留存储空间，以便将来 V3 继承 V2 时：
    // - V2 可以添加新变量而不影响 V3
    // - 保持整个继承链的存储布局稳定
    //
    uint256[47] private __gap_v2;   // Slot 52-98

    // ============================================================================
    // 🔄 reinitializer - 升级时的初始化函数
    // ============================================================================
    //
    // ❓ 为什么用 reinitializer(2) 而不是 initializer？
    //    - initializer 只能调用一次（在 V1 部署时已经用过了）
    //    - reinitializer(n) 允许在升级时进行第 n 次初始化
    //    - 数字 2 表示这是第二次初始化（V2）
    //    - 如果将来有 V3，就用 reinitializer(3)
    //
    // ❓ 什么时候调用这个函数？
    //    - 在执行升级时：proxy.upgradeToAndCall(v2Impl, initializeV2Data)
    //    - upgradeToAndCall 的第二个参数就是调用 initializeV2 的编码数据
    //
    // ❓ __EIP712_init 是什么？
    //    - 初始化 EIP-712 签名验证所需的 domain separator
    //    - "NFTMarket" 是合约名称，"2" 是版本号
    //    - 用于生成类型化数据签名（防止跨合约/跨链重放攻击）
    //
    // ❓ 如果忘记调用会怎样？
    //    - EIP712 功能不会正常工作
    //    - 签名验证会失败
    //    - 所以升级时必须调用 upgradeToAndCall，不能只用 upgradeTo
    //
    /**
     * @notice Reinitializer for V2 upgrade
     * @dev Called during upgrade to initialize V2-specific state
     */
    function initializeV2() public reinitializer(2) {
        __EIP712_init("NFTMarket", "2");
    }

    // ============ Signature-Based Listing Functions ============

    /**
     * @notice List an NFT for sale using seller's offline signature
     * @dev Buyer calls this to list the NFT based on seller's signed intent
     * The seller must have approved the marketplace via setApprovalForAll
     * @param tokenId ID of the NFT to list
     * @param price Price in payment tokens
     * @param deadline Signature expiration timestamp
     * @param v Signature v component
     * @param r Signature r component
     * @param s Signature s component
     */
    function listWithSignature(
        uint256 tokenId,
        uint256 price,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        if (price == 0) revert InvalidPrice();
        if (block.timestamp > deadline) revert SignatureExpired();
        if (listings[tokenId].isActive) revert NFTAlreadyListed();
        
        // Get the NFT owner
        address tokenOwner = nft.ownerOf(tokenId);
        
        // Verify marketplace has approval
        require(
            nft.isApprovedForAll(tokenOwner, address(this)) || 
            nft.getApproved(tokenId) == address(this),
            "Marketplace not approved"
        );

        // Get signer's current nonce
        uint256 nonce = nonces[tokenOwner];
        
        // Verify signature
        bytes32 structHash = keccak256(abi.encode(
            LISTING_TYPEHASH,
            tokenId,
            price,
            nonce,
            deadline
        ));
        
        bytes32 digest = _hashTypedDataV4(structHash);
        bytes32 signatureHash = keccak256(abi.encodePacked(v, r, s));
        
        if (usedSignatures[signatureHash]) revert SignatureAlreadyUsed();
        
        address signer = ECDSA.recover(digest, v, r, s);
        if (signer != tokenOwner) revert InvalidSignature();
        
        // Mark signature as used
        usedSignatures[signatureHash] = true;
        nonces[tokenOwner]++;

        // Transfer NFT to marketplace (escrow)
        nft.transferFrom(tokenOwner, address(this), tokenId);

        listings[tokenId] = Listing({
            seller: tokenOwner,
            price: price,
            isActive: true
        });
        
        totalListings++;

        emit NFTListedWithSignature(tokenId, tokenOwner, price, signatureHash);
    }

    /**
     * @notice Buy an NFT directly using seller's signature (no prior listing required)
     * @dev Combines listing and buying in one transaction
     * @param tokenId ID of the NFT to buy
     * @param price Price in payment tokens
     * @param deadline Signature expiration timestamp
     * @param v Signature v component
     * @param r Signature r component
     * @param s Signature s component
     */
    function buyWithSignature(
        uint256 tokenId,
        uint256 price,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        if (price == 0) revert InvalidPrice();
        if (block.timestamp > deadline) revert SignatureExpired();
        
        // Get the NFT owner
        address seller = nft.ownerOf(tokenId);
        
        // Verify marketplace has approval
        require(
            nft.isApprovedForAll(seller, address(this)) || 
            nft.getApproved(tokenId) == address(this),
            "Marketplace not approved"
        );

        // Get seller's current nonce
        uint256 nonce = nonces[seller];
        
        // Verify signature
        bytes32 structHash = keccak256(abi.encode(
            LISTING_TYPEHASH,
            tokenId,
            price,
            nonce,
            deadline
        ));
        
        bytes32 digest = _hashTypedDataV4(structHash);
        bytes32 signatureHash = keccak256(abi.encodePacked(v, r, s));
        
        if (usedSignatures[signatureHash]) revert SignatureAlreadyUsed();
        
        address signer = ECDSA.recover(digest, v, r, s);
        if (signer != seller) revert InvalidSignature();
        
        // Mark signature as used
        usedSignatures[signatureHash] = true;
        nonces[seller]++;

        // Calculate fee
        uint256 fee = (price * feePercent) / 10000;
        uint256 sellerAmount = price - fee;
        accumulatedFees += fee;

        // Transfer payment from buyer to seller
        bool success = paymentToken.transferFrom(msg.sender, seller, sellerAmount);
        if (!success) revert TransferFailed();
        
        // Transfer fee to contract
        if (fee > 0) {
            success = paymentToken.transferFrom(msg.sender, address(this), fee);
            if (!success) revert TransferFailed();
        }

        // Transfer NFT directly from seller to buyer
        nft.transferFrom(seller, msg.sender, tokenId);

        emit NFTSold(tokenId, msg.sender, seller, price);
    }

    /**
     * @notice Cancel a specific signature by invalidating it
     * @dev Increment nonce to invalidate all pending signatures
     */
    function cancelAllSignatures() external {
        nonces[msg.sender]++;
    }

    /**
     * @notice Cancel a specific signature
     * @param signatureHash Hash of the signature to cancel
     */
    function cancelSignature(bytes32 signatureHash) external {
        usedSignatures[signatureHash] = true;
        emit SignatureCancelled(msg.sender, signatureHash);
    }

    // ============ View Functions ============

    /**
     * @notice Get the EIP-712 domain separator
     * @return Domain separator
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @notice Get the current nonce for an address
     * @param owner Address to get nonce for
     * @return Current nonce
     */
    function getNonce(address owner) external view returns (uint256) {
        return nonces[owner];
    }

    /**
     * @notice Check if a signature has been used
     * @param signatureHash Hash of the signature
     * @return Whether the signature has been used
     */
    function isSignatureUsed(bytes32 signatureHash) external view returns (bool) {
        return usedSignatures[signatureHash];
    }

    /**
     * @notice Compute the digest for a listing signature
     * @param tokenId ID of the NFT
     * @param price Price in payment tokens
     * @param nonce Signer's nonce
     * @param deadline Signature expiration timestamp
     * @return The EIP-712 typed data hash
     */
    function getListingDigest(
        uint256 tokenId,
        uint256 price,
        uint256 nonce,
        uint256 deadline
    ) external view returns (bytes32) {
        bytes32 structHash = keccak256(abi.encode(
            LISTING_TYPEHASH,
            tokenId,
            price,
            nonce,
            deadline
        ));
        return _hashTypedDataV4(structHash);
    }

    // ============================================================================
    // 📝 版本号函数 - 覆盖 V1 的实现
    // ============================================================================
    //
    // ❓ 为什么要 override？
    //    - V1 中的 version() 声明为 virtual，允许子合约覆盖
    //    - V2 覆盖它返回新的版本号
    //    - 这是一个好的实践，方便在链上检查当前运行的版本
    //
    /**
     * @notice Get the contract version
     * @return Version string
     */
    function version() external pure override returns (string memory) {
        return "2.0.0";
    }
}
