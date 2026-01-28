// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// ============================================================================
// 📚 可升级 ERC721 合约需要的库
// ============================================================================
//
// 1. ERC721Upgradeable - 可升级版本的 ERC721
//    - 提供标准 NFT 功能：ownerOf, balanceOf, transferFrom, approve 等
//    - 需要在 initialize 中调用 __ERC721_init(name, symbol)
//
// 2. ERC721EnumerableUpgradeable - 可枚举扩展
//    - 提供 totalSupply(), tokenByIndex(), tokenOfOwnerByIndex()
//    - 可以遍历所有 NFT 或某用户的所有 NFT
//    - 需要在 initialize 中调用 __ERC721Enumerable_init()
//    - ⚠️ 需要重写 _update, _increaseBalance, supportsInterface
//
// 3. OwnableUpgradeable - 可升级的所有权管理
//    - 提供 owner() 和 onlyOwner 修饰符
//    - 需要在 initialize 中调用 __Ownable_init(address)
//
// 4. Initializable - 初始化器
//    - 提供 initializer 修饰符
//    - 确保 initialize 只能调用一次
//
// 5. UUPSUpgradeable - UUPS 升级模式
//    - 提供升级功能
//    - 需要实现 _authorizeUpgrade 函数
//
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title MarketNFT
 * @notice Upgradeable ERC721 NFT contract for the NFT marketplace
 * @dev Uses UUPS proxy pattern for upgradeability
 * 
 * ============================================================================
 * 📐 继承关系图
 * ============================================================================
 * 
 *                    ┌─────────────────┐
 *                    │  Initializable  │
 *                    └────────┬────────┘
 *                             │
 *   ┌─────────────────────────┼─────────────────────────┐
 *   │                         │                         │
 *   ▼                         ▼                         ▼
 * ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
 * │ERC721Upgradeable│  │OwnableUpgradeable│  │UUPSUpgradeable │
 * └────────┬────────┘  └─────────────────┘  └─────────────────┘
 *          │
 *          ▼
 * ┌─────────────────────────────┐
 * │ERC721EnumerableUpgradeable │
 * └─────────────────────────────┘
 *          │
 *          ▼
 * ┌─────────────────────────────┐
 * │       MarketNFT             │  ← 我们的合约
 * └─────────────────────────────┘
 * 
 * ============================================================================
 * ⚠️ 多重继承注意事项
 * ============================================================================
 * 
 * 当合约继承多个父合约，且它们有同名函数时，需要用 override 指定：
 * - _update: ERC721 和 ERC721Enumerable 都有
 * - _increaseBalance: ERC721 和 ERC721Enumerable 都有
 * - supportsInterface: ERC721 和 ERC721Enumerable 都有
 * 
 * 必须显式声明 override(合约A, 合约B) 并调用 super.函数名()
 * 
 */
contract MarketNFT is 
    Initializable,                    // 提供 initializer 修饰符
    ERC721Upgradeable,                // 基础 NFT 功能
    ERC721EnumerableUpgradeable,      // 可枚举扩展（遍历所有 NFT）
    OwnableUpgradeable,               // 所有权管理
    UUPSUpgradeable                   // UUPS 升级模式
{
    // ============================================================================
    // 📦 状态变量
    // ============================================================================
    
    /// @notice 下一个要铸造的 tokenId
    /// @dev 从 1 开始，每次铸造后自增
    uint256 private _nextTokenId;     // Slot 位置由继承的父合约决定
    
    /// @notice NFT 元数据的基础 URI
    /// @dev tokenURI = baseURI + tokenId
    string private _baseTokenURI;

    // ============ Events ============
    event BaseURIUpdated(string oldURI, string newURI);

    // ============================================================================
    // 🔒 构造函数 - 禁用实现合约的初始化
    // ============================================================================
    //
    // ❓ 为什么要 @custom:oz-upgrades-unsafe-allow constructor？
    //    - 这是给 OpenZeppelin 升级插件的注释
    //    - 告诉插件：我知道在构造函数里做事情，但这是安全的
    //    - 因为我们只是禁用初始化，没有设置任何状态
    //
    // ❓ _disableInitializers() 做了什么？
    //    - 将 _initialized 设置为最大值 (type(uint64).max)
    //    - 这样任何 initializer 或 reinitializer 都会失败
    //    - 防止攻击者直接调用实现合约的 initialize
    //
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ============================================================================
    // 🚀 初始化函数 - 替代构造函数
    // ============================================================================
    //
    // ❓ 为什么有这么多 __XXX_init 调用？
    //    - 每个可升级的父合约都有自己的初始化函数
    //    - 必须按正确的顺序调用它们
    //    - 如果漏掉任何一个，那个功能就不会正常工作
    //
    // ❓ __ERC721_init(name, symbol) 做了什么？
    //    - 设置 NFT 的名称和符号
    //    - 初始化 ERC721 的内部状态
    //
    // ❓ __ERC721Enumerable_init() 做了什么？
    //    - 初始化枚举扩展的内部状态
    //    - 使 totalSupply(), tokenByIndex() 等函数可用
    //
    // ❓ __Ownable_init(owner) 做了什么？
    //    - 设置合约的 owner
    //    - 使 onlyOwner 修饰符可用
    //
    // ❓ 为什么没有 __UUPSUpgradeable_init()？
    //    - UUPSUpgradeable 不需要初始化
    //    - 它只提供升级逻辑，没有需要初始化的状态
    //
    /**
     * @notice Initialize the NFT contract
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param baseURI_ Base URI for token metadata
     * @param initialOwner Address of the initial owner
     */
    function initialize(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        address initialOwner
    ) public initializer {
        // 初始化 ERC721：设置名称和符号
        __ERC721_init(name_, symbol_);
        
        // 初始化 ERC721Enumerable：启用枚举功能
        __ERC721Enumerable_init();
        
        // 初始化 Ownable：设置 owner
        __Ownable_init(initialOwner);
        
        // 设置自己的状态变量
        _baseTokenURI = baseURI_;
        _nextTokenId = 1;  // tokenId 从 1 开始
    }

    // ============ Minting Functions ============

    /**
     * @notice Mint a new NFT to the specified address
     * @param to Address to receive the NFT
     * @return tokenId The ID of the minted token
     */
    function mint(address to) external onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        return tokenId;
    }

    /**
     * @notice Batch mint NFTs to the specified address
     * @param to Address to receive the NFTs
     * @param amount Number of NFTs to mint
     * @return startTokenId The first token ID minted
     */
    function batchMint(address to, uint256 amount) external onlyOwner returns (uint256) {
        uint256 startTokenId = _nextTokenId;
        for (uint256 i = 0; i < amount; i++) {
            _safeMint(to, _nextTokenId++);
        }
        return startTokenId;
    }

    // ============ Admin Functions ============

    /**
     * @notice Update the base URI for token metadata
     * @param newBaseURI New base URI
     */
    function setBaseURI(string memory newBaseURI) external onlyOwner {
        string memory oldURI = _baseTokenURI;
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(oldURI, newBaseURI);
    }

    // ============ View Functions ============

    /**
     * @notice Get the next token ID to be minted
     * @return The next token ID
     */
    function nextTokenId() external view returns (uint256) {
        return _nextTokenId;
    }

    // ============================================================================
    // 🔧 内部函数重写
    // ============================================================================

    // ============================================================================
    // _baseURI() - 返回元数据基础 URI
    // ============================================================================
    //
    // ❓ 这个函数是做什么的？
    //    - ERC721 的 tokenURI(tokenId) 会调用这个函数
    //    - tokenURI = _baseURI() + tokenId.toString()
    //    - 例如：baseURI = "https://api.example.com/nft/"
    //           tokenURI(1) = "https://api.example.com/nft/1"
    //
    // ❓ 为什么要 override？
    //    - ERC721Upgradeable 中的 _baseURI() 默认返回空字符串
    //    - 我们需要覆盖它返回我们设置的 baseURI
    //
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    // ============================================================================
    // _authorizeUpgrade() - 升级授权
    // ============================================================================
    //
    // 详细说明见 NFTMarketV1.sol
    //
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ============================================================================
    // 📝 必须重写的函数（多重继承冲突解决）
    // ============================================================================
    //
    // 当继承 ERC721 和 ERC721Enumerable 时，有几个函数在两个合约中都存在。
    // Solidity 要求我们显式声明如何处理这种冲突。
    //

    // ============================================================================
    // _update() - NFT 转移时的钩子函数
    // ============================================================================
    //
    // ❓ 这个函数什么时候被调用？
    //    - 每次 NFT 被转移时（mint, burn, transfer）
    //    - _mint(to, tokenId) → _update(to, tokenId, address(0))
    //    - _burn(tokenId) → _update(address(0), tokenId, owner)
    //    - _transfer(from, to, tokenId) → _update(to, tokenId, from)
    //
    // ❓ 参数含义？
    //    - to: 接收者地址（如果是 burn，则为 address(0)）
    //    - tokenId: NFT 的 ID
    //    - auth: 授权者地址（用于权限检查）
    //
    // ❓ 为什么 ERC721Enumerable 需要重写这个？
    //    - ERC721Enumerable 需要维护额外的数据结构：
    //      - _allTokens: 所有 tokenId 的数组
    //      - _allTokensIndex: tokenId → 在 _allTokens 中的索引
    //      - _ownedTokens: owner → tokenId 数组
    //      - _ownedTokensIndex: tokenId → 在 owner 的数组中的索引
    //    - 每次转移都要更新这些数据
    //
    // ❓ override(ERC721Upgradeable, ERC721EnumerableUpgradeable) 是什么意思？
    //    - 告诉编译器：这个函数覆盖了两个父合约中的同名函数
    //    - 必须列出所有定义了这个函数的父合约
    //
    // ❓ super._update() 调用的是哪个？
    //    - Solidity 的 C3 线性化规则决定调用顺序
    //    - 按照 is 后面的顺序，从右到左：
    //      UUPSUpgradeable → OwnableUpgradeable → ERC721EnumerableUpgradeable → ERC721Upgradeable
    //    - super._update 会先调用 ERC721EnumerableUpgradeable._update
    //    - 然后 ERC721EnumerableUpgradeable._update 内部再调用 ERC721Upgradeable._update
    //
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (address)
    {
        // super 会按照继承链依次调用
        // ERC721EnumerableUpgradeable._update 会更新枚举相关的数据
        // 然后调用 ERC721Upgradeable._update 处理核心转移逻辑
        return super._update(to, tokenId, auth);
    }

    // ============================================================================
    // _increaseBalance() - 增加账户余额时的钩子函数
    // ============================================================================
    //
    // ❓ 这个函数什么时候被调用？
    //    - 当批量铸造 NFT 时（_mintBatch 内部调用）
    //    - 用于一次性增加账户的 NFT 数量，而不是逐个调用 _update
    //
    // ❓ 为什么需要重写？
    //    - ERC721Enumerable 需要知道每个账户有多少 NFT
    //    - 需要更新 _ownedTokens 相关的数据结构
    //
    // ❓ uint128 value 是什么？
    //    - 要增加的 NFT 数量
    //    - 用 uint128 而不是 uint256 是为了节省 gas（打包存储）
    //
    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._increaseBalance(account, value);
    }

    // ============================================================================
    // supportsInterface() - ERC165 接口支持检查
    // ============================================================================
    //
    // ❓ 这个函数是做什么的？
    //    - ERC165 标准：合约声明自己支持哪些接口
    //    - 其他合约可以调用这个函数来检查我们是否支持某个接口
    //    - 例如：市场合约可能检查 NFT 是否支持 ERC721 接口
    //
    // ❓ interfaceId 是什么？
    //    - 接口的唯一标识符
    //    - 计算方式：接口中所有函数选择器的 XOR
    //    - 例如：IERC721 的 interfaceId = 0x80ac58cd
    //
    // ❓ 为什么需要重写？
    //    - ERC721 声明支持 IERC721
    //    - ERC721Enumerable 声明支持 IERC721Enumerable
    //    - 我们需要返回两者都支持
    //
    // ❓ super.supportsInterface 做了什么？
    //    - 沿着继承链检查每个父合约
    //    - 如果任何一个返回 true，就返回 true
    //    - ERC721Enumerable.supportsInterface 会检查 IERC721Enumerable
    //    - 然后调用 ERC721.supportsInterface 检查 IERC721
    //
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
