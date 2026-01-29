// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title UserRegistryV2
 * @notice 可升级用户注册合约 - 版本 2
 * @dev ✅ 正确的升级方式：在结构体末尾添加新字段
 * 
 * ============================================================================
 * 📐 V2 存储布局（在结构体末尾添加 email）
 * ============================================================================
 * 
 *   对于 users[1] 的存储位置 = keccak256(1 . 1):
 *   ┌─────────────────────────────────────────┐
 *   │ Slot S:   name (字符串指针)     ← 不变   │
 *   │ Slot S+1: age (uint256)        ← 不变   │
 *   │ Slot S+2: isActive (bool)      ← 不变   │
 *   │ Slot S+3: email (字符串指针)    ← 新增   │
 *   │ Slot S+4: score (uint256)      ← 新增   │
 *   └─────────────────────────────────────────┘
 * 
 *   ✅ 原有字段的位置没有改变，数据安全！
 *   ✅ 新字段使用新的存储槽，初始值为默认值
 * 
 */
contract UserRegistryV2 is 
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    // ============ Structs ============
    /// @notice V2 版本的 User 结构体 - 在末尾添加了 email 和 score
    struct User {
        string name;      // 用户名 (保持不变)
        uint256 age;      // 年龄 (保持不变)
        bool isActive;    // 是否激活 (保持不变)
        string email;     // ✅ 新增：邮箱
        uint256 score;    // ✅ 新增：积分
    }

    // ============ State Variables ============
    /// @notice 下一个用户 ID (位置不变)
    uint256 public nextUserId;                    // Slot 0
    
    /// @notice 用户 ID => User 信息 (位置不变)
    mapping(uint256 => User) public users;        // Slot 1

    // ============ Events ============
    event UserRegistered(uint256 indexed userId, string name, uint256 age);
    event UserUpdated(uint256 indexed userId, string name, uint256 age);
    event UserEmailUpdated(uint256 indexed userId, string email);
    event UserScoreUpdated(uint256 indexed userId, uint256 score);

    // ============ Storage Gap ============
    /// @dev 为未来升级预留存储空间
    uint256[48] private __gap;                    // Slot 2-49

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice 初始化合约 (V1 已调用，这里不需要)
     */
    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        nextUserId = 1;
    }

    /**
     * @notice V2 升级初始化
     */
    function initializeV2() public reinitializer(2) {
        // V2 不需要特殊初始化，但保留这个函数作为最佳实践
    }

    // ============ User Functions ============

    /**
     * @notice 注册新用户 (包含新字段)
     */
    function registerUser(string calldata name, uint256 age) external returns (uint256 userId) {
        userId = nextUserId++;
        
        users[userId] = User({
            name: name,
            age: age,
            isActive: true,
            email: "",      // 新字段默认值
            score: 0        // 新字段默认值
        });

        emit UserRegistered(userId, name, age);
    }

    /**
     * @notice 注册新用户 (带邮箱)
     */
    function registerUserWithEmail(
        string calldata name, 
        uint256 age,
        string calldata email
    ) external returns (uint256 userId) {
        userId = nextUserId++;
        
        users[userId] = User({
            name: name,
            age: age,
            isActive: true,
            email: email,
            score: 0
        });

        emit UserRegistered(userId, name, age);
    }

    /**
     * @notice 更新用户邮箱
     */
    function updateEmail(uint256 userId, string calldata email) external {
        require(users[userId].isActive, "User not found");
        users[userId].email = email;
        emit UserEmailUpdated(userId, email);
    }

    /**
     * @notice 增加用户积分
     */
    function addScore(uint256 userId, uint256 points) external {
        require(users[userId].isActive, "User not found");
        users[userId].score += points;
        emit UserScoreUpdated(userId, users[userId].score);
    }

    /**
     * @notice 获取用户信息 (V1 兼容)
     */
    function getUser(uint256 userId) external view returns (
        string memory name,
        uint256 age,
        bool isActive
    ) {
        User storage user = users[userId];
        return (user.name, user.age, user.isActive);
    }

    /**
     * @notice 获取用户完整信息 (V2 新增)
     */
    function getUserFull(uint256 userId) external view returns (
        string memory name,
        uint256 age,
        bool isActive,
        string memory email,
        uint256 score
    ) {
        User storage user = users[userId];
        return (user.name, user.age, user.isActive, user.email, user.score);
    }

    /**
     * @notice 获取合约版本
     */
    function version() external pure virtual returns (string memory) {
        return "2.0.0";
    }

    // ============ Admin Functions ============
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
