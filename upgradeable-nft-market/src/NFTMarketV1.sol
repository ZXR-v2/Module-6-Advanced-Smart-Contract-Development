// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// ============================================================================
// 📚 可升级合约必需的三个核心库
// ============================================================================
//
// 1. Initializable - 初始化器
//    - 提供 `initializer` 修饰符，确保 initialize 函数只能调用一次
//    - 提供 `reinitializer(n)` 修饰符，用于升级时初始化新版本的状态
//    - 提供 `_disableInitializers()` 函数，防止实现合约被直接初始化
//    - 为什么需要？因为代理模式下 constructor 不会被执行，需要用 initialize 替代
//
// 2. UUPSUpgradeable - UUPS 升级模式
//    - 提供 `upgradeToAndCall(address, bytes)` 函数执行升级
//    - 要求实现 `_authorizeUpgrade(address)` 函数来定义升级权限
//    - 升级逻辑在实现合约中（区别于透明代理模式，升级逻辑在代理合约中）
//    - 优点：gas 更便宜，代理合约更简单
//
// 3. OwnableUpgradeable - 可升级版本的所有权管理
//    - 提供 `owner()` 函数和 `onlyOwner` 修饰符
//    - 必须在 initialize 中调用 `__Ownable_init(address)` 初始化 owner
//    - 注意：必须使用 -Upgradeable 版本，不能用普通的 Ownable！
//
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title NFTMarketV1
 * @notice Upgradeable NFT Marketplace - Version 1
 * @dev Basic marketplace functionality: list, delist, buy NFTs
 * Uses UUPS proxy pattern for upgradeability
 * 
 * ============================================================================
 * 📐 UUPS 代理升级模式架构图
 * ============================================================================
 * 
 *   用户调用
 *      ↓
 *   ┌───────────────────┐
 *   │   ERC1967Proxy    │  ← 代理合约（存储所有状态，地址永不变）
 *   │   (不变的地址)     │
 *   └─────────┬─────────┘
 *             │ delegatecall（使用代理的存储，执行实现的代码）
 *             ↓
 *   ┌───────────────────┐     升级      ┌───────────────────┐
 *   │  NFTMarketV1      │ ───────────→ │  NFTMarketV2      │
 *   │  (实现合约)        │              │  (新实现合约)      │
 *   └───────────────────┘              └───────────────────┘
 * 
 *   关键点：
 *   • 代理合约地址永远不变，用户始终与同一地址交互
 *   • 所有状态存储在代理合约中，实现合约只提供逻辑
 *   • 升级 = 部署新实现合约 + 修改代理指向的地址
 *   • 状态数据在升级前后保持不变
 * 
 * ============================================================================
 */
contract NFTMarketV1 is 
    Initializable,        // 提供 initializer 修饰符
    OwnableUpgradeable,   // 提供 onlyOwner 修饰符和 owner()
    UUPSUpgradeable       // 提供 upgradeToAndCall 和要求实现 _authorizeUpgrade
{
    // ============ Structs ============
    struct Listing {
        address seller;
        uint256 price;
        bool isActive;
    }

    // ============ State Variables ============
    // 📝 注意：状态变量的顺序很重要！升级时不能改变顺序，只能在末尾添加
    
    /// @notice Payment token for purchases
    IERC20 public paymentToken;      // Slot 0
    
    /// @notice NFT contract
    IERC721 public nft;              // Slot 1
    
    /// @notice NFT tokenId => Listing info
    mapping(uint256 => Listing) public listings;  // Slot 2
    
    /// @notice Total number of active listings
    uint256 public totalListings;    // Slot 3
    
    /// @notice Fee percentage (in basis points, e.g., 250 = 2.5%)
    uint256 public feePercent;       // Slot 4
    
    /// @notice Accumulated fees
    uint256 public accumulatedFees;  // Slot 5

    // ============ Events ============
    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTDelisted(uint256 indexed tokenId);
    event NFTSold(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price);
    event FeePercentUpdated(uint256 oldFee, uint256 newFee);
    event FeesWithdrawn(address indexed to, uint256 amount);

    // ============ Errors ============
    error InvalidPrice();
    error NFTNotListed();
    error NFTAlreadyListed();
    error NotSeller();
    error TransferFailed();
    error InvalidAddress();
    error InsufficientBalance();

    // ============ Reentrancy Guard ============
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;         // Slot 6

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }

    // ============================================================================
    // 📦 Storage Gap - 为未来升级预留存储空间
    // ============================================================================
    //
    // ❓ 为什么需要 __gap？
    //    代理合约确实存储状态，但问题出在继承关系上！
    //
    // ❓ 场景说明：
    //    当 NFTMarketV2 继承 NFTMarketV1 时：
    //    - V1 的变量占用 Slot 0-6
    //    - V2 的新变量紧跟在 V1 后面，从 Slot 7 开始
    //
    // ❓ 如果没有 __gap 会发生什么？
    //    假设我们想给 V1 添加新变量 `newFeature`：
    //    
    //    升级前存储布局：              升级后存储布局（灾难！）：
    //    ┌─────────────────────┐      ┌─────────────────────┐
    //    │ Slot 6: _status     │      │ Slot 6: _status     │
    //    │ Slot 7: V2的nonces  │      │ Slot 7: newFeature  │ ← V1新增！
    //    └─────────────────────┘      │ Slot 8: V2的nonces  │ ← 被推后，数据损坏！
    //                                 └─────────────────────┘
    //
    // ✅ 有 __gap 时：
    //    ┌─────────────────────┐      ┌─────────────────────┐
    //    │ Slot 6: _status     │      │ Slot 6: _status     │
    //    │ Slot 7: __gap[0]    │      │ Slot 7: newFeature  │ ← 使用预留空间
    //    │ ...                 │      │ Slot 8: __gap[0]    │ ← gap 减少 1
    //    │ Slot 49: __gap[42]  │      │ ...                 │
    //    │ Slot 50: V2的nonces │      │ Slot 50: V2的nonces │ ← 位置不变！安全！
    //    └─────────────────────┘      └─────────────────────┘
    //
    // 📝 规则：每次在父合约添加新变量，就把 __gap 数组大小减少相应数量
    //
    /// @dev Reserved storage space for future upgrades
    uint256[43] private __gap;       // Slot 7-49 预留给未来 V1 的升级

    // ============================================================================
    // 🔒 构造函数 - 禁用实现合约的初始化
    // ============================================================================
    //
    // ❓ 为什么要调用 _disableInitializers()？
    //    - 实现合约本身不应该被初始化，只有通过代理调用时才应该初始化
    //    - 防止攻击者直接调用实现合约的 initialize 函数
    //    - 如果攻击者初始化了实现合约，可能会造成安全问题
    //
    // ❓ 为什么构造函数还能执行？
    //    - 构造函数在部署时执行，是部署实现合约时执行的
    //    - 它只是设置一个标志，标记这个合约不能被初始化
    //    - 代理合约 delegatecall 时不会执行构造函数，只执行 initialize
    //
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ============================================================================
    // 🚀 初始化函数 - 替代构造函数
    // ============================================================================
    //
    // ❓ 为什么用 initialize 而不是 constructor？
    //    - 代理模式下，构造函数的代码不会在代理合约的上下文中执行
    //    - 构造函数设置的状态会存在实现合约中，而不是代理合约中
    //    - 所以需要 initialize 函数，通过 delegatecall 在代理合约中执行
    //
    // ❓ initializer 修饰符做了什么？
    //    - 检查是否已经初始化过
    //    - 如果已初始化，revert
    //    - 如果未初始化，标记为已初始化，然后执行函数
    //    - 确保 initialize 只能调用一次
    //
    // ❓ __Ownable_init 是什么？
    //    - 可升级版本的 Ownable 初始化函数
    //    - 设置 owner 为传入的地址
    //    - 必须在 initialize 中调用，因为构造函数不会执行
    //
    /**
     * @notice Initialize the marketplace
     * @param _paymentToken Address of the payment token
     * @param _nft Address of the NFT contract
     * @param _feePercent Fee percentage in basis points
     * @param initialOwner Address of the initial owner
     */
    function initialize(
        address _paymentToken,
        address _nft,
        uint256 _feePercent,
        address initialOwner
    ) public initializer {
        if (_paymentToken == address(0) || _nft == address(0)) revert InvalidAddress();
        
        // 初始化 Ownable，设置 owner
        __Ownable_init(initialOwner);
        
        paymentToken = IERC20(_paymentToken);
        nft = IERC721(_nft);
        feePercent = _feePercent;
        _status = NOT_ENTERED;
    }

    // ============ Listing Functions ============

    /**
     * @notice List an NFT for sale
     * @dev NFT is transferred to marketplace (escrow)
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
        
        totalListings++;

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
        totalListings--;
        
        // Return NFT to seller
        nft.transferFrom(address(this), msg.sender, tokenId);

        emit NFTDelisted(tokenId);
    }

    // ============ Purchase Functions ============

    /**
     * @notice Purchase a listed NFT
     * @param tokenId ID of the NFT to purchase
     */
    function buy(uint256 tokenId) external nonReentrant {
        Listing storage listing = listings[tokenId];
        if (!listing.isActive) revert NFTNotListed();

        uint256 price = listing.price;
        address seller = listing.seller;

        listing.isActive = false;
        totalListings--;

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

        // Transfer NFT to buyer
        nft.transferFrom(address(this), msg.sender, tokenId);

        emit NFTSold(tokenId, msg.sender, seller, price);
    }

    // ============ Admin Functions ============

    /**
     * @notice Update the fee percentage
     * @param newFeePercent New fee percentage in basis points
     */
    function setFeePercent(uint256 newFeePercent) external onlyOwner {
        require(newFeePercent <= 1000, "Fee too high"); // Max 10%
        uint256 oldFee = feePercent;
        feePercent = newFeePercent;
        emit FeePercentUpdated(oldFee, newFeePercent);
    }

    /**
     * @notice Withdraw accumulated fees
     * @param to Address to send fees to
     */
    function withdrawFees(address to) external onlyOwner {
        if (to == address(0)) revert InvalidAddress();
        uint256 amount = accumulatedFees;
        if (amount == 0) revert InsufficientBalance();
        
        accumulatedFees = 0;
        bool success = paymentToken.transfer(to, amount);
        if (!success) revert TransferFailed();
        
        emit FeesWithdrawn(to, amount);
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
     * @notice Get the contract version
     * @return Version string
     */
    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }

    // ============================================================================
    // 🔐 升级授权函数 - UUPS 模式的核心
    // ============================================================================
    //
    // ❓ 为什么要 override？
    //    - UUPSUpgradeable 定义了抽象函数 `_authorizeUpgrade`
    //    - 子合约必须实现这个函数，所以需要 override
    //    - 这是 Solidity 的语法要求
    //
    // ❓ 为什么函数体是空的 {}？
    //    - 权限检查由 `onlyOwner` 修饰符完成
    //    - onlyOwner 会检查 msg.sender == owner()
    //    - 如果不是 owner，会直接 revert，根本不会执行到函数体
    //    - 所以函数体不需要任何代码
    //
    // ❓ 这个函数什么时候被调用？
    //    - 当调用 upgradeToAndCall(newImpl, data) 时
    //    - upgradeToAndCall 内部会先调用 _authorizeUpgrade(newImpl)
    //    - 检查通过后才会执行实际的升级操作
    //
    // ❓ 升级的完整流程是什么？
    //    
    //    proxy.upgradeToAndCall(newImpl, initData)
    //           │
    //           ▼
    //    ┌─────────────────────────────────────────────────┐
    //    │ 1. _authorizeUpgrade(newImpl)                   │
    //    │    └─→ onlyOwner 检查 msg.sender == owner       │
    //    │        ├─ 不是 owner → revert ❌                │
    //    │        └─ 是 owner → 继续 ✅                    │
    //    │                                                 │
    //    │ 2. 验证 newImpl 是合法的 UUPS 合约              │
    //    │    └─→ 防止升级到无法再升级的合约（锁死）        │
    //    │                                                 │
    //    │ 3. 更新实现合约地址                              │
    //    │    └─→ sstore(IMPL_SLOT, newImpl)              │
    //    │        修改代理合约存储中的实现地址              │
    //    │                                                 │
    //    │ 4. 调用初始化函数（如果 initData 不为空）        │
    //    │    └─→ delegatecall(newImpl, initData)         │
    //    │        比如调用 initializeV2()                  │
    //    └─────────────────────────────────────────────────┘
    //
    // ❓ 可以自定义权限逻辑吗？
    //    当然可以！比如：
    //    
    //    // 多签才能升级
    //    function _authorizeUpgrade(address) internal override {
    //        require(multisig.isApproved(msg.sender), "Need multisig");
    //    }
    //    
    //    // 时间锁
    //    function _authorizeUpgrade(address newImpl) internal override onlyOwner {
    //        require(block.timestamp >= upgradeTimelock[newImpl], "Too early");
    //    }
    //    
    //    // 禁止升级（锁死合约）
    //    function _authorizeUpgrade(address) internal override {
    //        revert("Upgrades disabled");
    //    }
    //
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
