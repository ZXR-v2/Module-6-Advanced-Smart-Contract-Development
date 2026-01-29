// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title UserRegistryV2Bad
 * @notice 可升级用户注册合约 - 版本 2 (错误示范)
 * @dev ❌ 错误的升级方式：在结构体开头添加新字段
 * 
 * ============================================================================
 * 📐 V2Bad 存储布局问题（在结构体开头添加 id）
 * ============================================================================
 * 
 *   V1 用户数据 users[1] 的实际存储：
 *   ┌─────────────────────────────────────────┐
 *   │ Slot S:   "Alice" (name)                │
 *   │ Slot S+1: 25 (age)                      │
 *   │ Slot S+2: true (isActive)               │
 *   └─────────────────────────────────────────┘
 * 
 *   V2Bad 读取时的解释（结构体定义改变了）：
 *   ┌─────────────────────────────────────────┐
 *   │ Slot S:   "Alice" → 读作 id ❌ 乱码!     │
 *   │ Slot S+1: 25 → 读作 name 的指针 ❌ 错误! │
 *   │ Slot S+2: true → 读作 age ❌ 变成 1!    │
 *   │ (Slot S+3: 预期 isActive, 实际读到0)     │
 *   └─────────────────────────────────────────┘
 * 
 *   ❌ 所有字段的位置都错位了，数据完全损坏！
 * 
 */
contract UserRegistryV2Bad is 
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    // ============ Structs ============
    /// @notice V2Bad 版本的 User 结构体 - ❌ 在开头添加了 id
    struct User {
        uint256 id;       // ❌ 错误：在开头添加新字段
        string name;      // 位置变了：原本是 Slot S，现在是 Slot S+1
        uint256 age;      // 位置变了：原本是 Slot S+1，现在是 Slot S+2
        bool isActive;    // 位置变了：原本是 Slot S+2，现在是 Slot S+3
    }

    // ============ State Variables ============
    /// @notice 下一个用户 ID
    uint256 public nextUserId;                    // Slot 0
    
    /// @notice 用户 ID => User 信息
    mapping(uint256 => User) public users;        // Slot 1

    // ============ Events ============
    event UserRegistered(uint256 indexed userId, string name, uint256 age);

    // ============ Storage Gap ============
    uint256[48] private __gap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        nextUserId = 1;
    }

    function initializeV2() public reinitializer(2) {
        // V2 初始化
    }

    // ============ User Functions ============

    function registerUser(string calldata name, uint256 age) external returns (uint256 userId) {
        userId = nextUserId++;
        
        users[userId] = User({
            id: userId,     // 新字段
            name: name,
            age: age,
            isActive: true
        });

        emit UserRegistered(userId, name, age);
    }

    /**
     * @notice 获取用户信息
     * @dev 升级后，这个函数读取 V1 创建的数据会返回错误的值！
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
     * @notice 获取用户 ID 字段
     * @dev 升级后，读取 V1 数据时这里会返回乱码（原 name 的数据被解释为 uint256）
     */
    function getUserId(uint256 userId) external view returns (uint256) {
        return users[userId].id;
    }

    function version() external pure virtual returns (string memory) {
        return "2.0.0-bad";
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
