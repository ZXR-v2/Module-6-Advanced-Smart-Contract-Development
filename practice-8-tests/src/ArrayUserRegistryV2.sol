// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title ArrayUserRegistryV2
 * @notice 在 User 结构体中添加新字段的 V2 版本 - 这会导致存储布局错乱！
 * @dev ⚠️ 危险示例：演示为什么不能在数组中的结构体添加新字段
 * 
 * ============================================================================
 * 📐 存储布局问题
 * ============================================================================
 * 
 *   V2 的 User 结构体占用 5 个 slot（比 V1 多 2 个）:
 *   
 *   V2 期望的布局:
 *   ┌─────────────────────────────────────────┐
 *   │ Slot H+0: users[0].name                 │
 *   │ Slot H+1: users[0].age                  │
 *   │ Slot H+2: users[0].isActive             │
 *   │ Slot H+3: users[0].email (新字段!)       │
 *   │ Slot H+4: users[0].score (新字段!)       │
 *   │ Slot H+5: users[1].name                 │  ← V2 认为 User[1] 从这里开始
 *   │ ...                                     │
 *   └─────────────────────────────────────────┘
 * 
 *   但实际上 V1 的数据是:
 *   ┌─────────────────────────────────────────┐
 *   │ Slot H+0: users[0].name                 │
 *   │ Slot H+1: users[0].age                  │
 *   │ Slot H+2: users[0].isActive             │
 *   │ Slot H+3: users[1].name ← 原来的User[1] │  ← V2 错误地认为是 users[0].email!
 *   │ Slot H+4: users[1].age                  │  ← V2 错误地认为是 users[0].score!
 *   │ Slot H+5: users[1].isActive             │  ← V2 错误地认为是 users[1].name!
 *   │ ...                                     │
 *   └─────────────────────────────────────────┘
 * 
 *   结果：数据完全错乱！
 * 
 */
contract ArrayUserRegistryV2 is 
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    // ============ Structs ============
    /// @notice V2 版本的 User 结构体 - 添加了 email 和 score 字段
    /// @dev ⚠️ 这会导致存储布局与 V1 不兼容！
    struct User {
        string name;      // Slot +0: 用户名
        uint256 age;      // Slot +1: 年龄
        bool isActive;    // Slot +2: 是否激活
        string email;     // Slot +3: 邮箱 (新增!) ← 问题根源
        uint256 score;    // Slot +4: 积分 (新增!) ← 问题根源
    }

    // ============ State Variables ============
    /// @notice 用户数组
    User[] public users;                              // Slot 0

    // ============ Events ============
    event UserRegistered(uint256 indexed index, string name, uint256 age);
    event UserEmailUpdated(uint256 indexed index, string email);

    // ============ Storage Gap ============
    uint256[49] private __gap;                        // Slot 1-49

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice 初始化合约
     */
    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    /**
     * @notice V2 升级初始化
     */
    function initializeV2() public reinitializer(2) {
        // V2 升级逻辑
    }

    // ============ User Functions ============

    /**
     * @notice 注册新用户（V2 版本，包含 email）
     */
    function registerUser(string calldata name, uint256 age) external returns (uint256 index) {
        index = users.length;
        
        users.push(User({
            name: name,
            age: age,
            isActive: true,
            email: "",
            score: 0
        }));

        emit UserRegistered(index, name, age);
    }

    /**
     * @notice 获取用户信息（V2 版本）
     * @dev 升级后调用这个函数会返回错误的数据！
     */
    function getUser(uint256 index) external view returns (
        string memory name,
        uint256 age,
        bool isActive
    ) {
        require(index < users.length, "User does not exist");
        User storage user = users[index];
        return (user.name, user.age, user.isActive);
    }

    /**
     * @notice 获取用户完整信息（包含新字段）
     * @dev 对于 V1 迁移过来的数据，这里会返回错乱的数据！
     */
    function getUserFull(uint256 index) external view returns (
        string memory name,
        uint256 age,
        bool isActive,
        string memory email,
        uint256 score
    ) {
        require(index < users.length, "User does not exist");
        User storage user = users[index];
        return (user.name, user.age, user.isActive, user.email, user.score);
    }

    /**
     * @notice 设置用户邮箱
     */
    function setUserEmail(uint256 index, string calldata email) external {
        require(index < users.length, "User does not exist");
        users[index].email = email;
        emit UserEmailUpdated(index, email);
    }

    /**
     * @notice 获取用户数量
     */
    function getUserCount() external view returns (uint256) {
        return users.length;
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
