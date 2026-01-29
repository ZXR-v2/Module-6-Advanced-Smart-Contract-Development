// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title ArrayUserRegistryV1
 * @notice 使用动态数组存储用户的可升级合约 - 版本 1
 * @dev 用于验证数组中结构体扩展会导致存储布局错乱的问题
 * 
 * ============================================================================
 * 📐 存储布局
 * ============================================================================
 * 
 *   ┌─────────────────────────────────────────┐
 *   │ Slot 0:  users.length (数组长度)         │
 *   │ Slot 1-48: __gap (预留)                  │
 *   └─────────────────────────────────────────┘
 * 
 *   数组元素存储在 keccak256(0) 开始的位置:
 *   设 H = keccak256(0)
 *   
 *   V1 的 User 结构体占用 3 个 slot:
 *   ┌─────────────────────────────────────────┐
 *   │ Slot H+0: users[0].name (字符串指针)     │
 *   │ Slot H+1: users[0].age                  │
 *   │ Slot H+2: users[0].isActive             │
 *   │ Slot H+3: users[1].name (字符串指针)     │  ← User[1] 紧接着 User[0]
 *   │ Slot H+4: users[1].age                  │
 *   │ Slot H+5: users[1].isActive             │
 *   │ ...                                     │
 *   └─────────────────────────────────────────┘
 * 
 */
contract ArrayUserRegistryV1 is 
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    // ============ Structs ============
    /// @notice V1 版本的 User 结构体 - 占用 3 个 slot
    struct User {
        string name;      // Slot +0: 用户名（字符串指针）
        uint256 age;      // Slot +1: 年龄
        bool isActive;    // Slot +2: 是否激活
    }

    // ============ State Variables ============
    /// @notice 用户数组
    User[] public users;                              // Slot 0 存储长度

    // ============ Events ============
    event UserRegistered(uint256 indexed index, string name, uint256 age);

    // ============ Storage Gap ============
    /// @dev 为未来升级预留存储空间
    uint256[49] private __gap;                        // Slot 1-49

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice 初始化合约
     * @param initialOwner 初始 owner 地址
     */
    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    // ============ User Functions ============

    /**
     * @notice 注册新用户
     * @param name 用户名
     * @param age 年龄
     * @return index 新用户在数组中的索引
     */
    function registerUser(string calldata name, uint256 age) external returns (uint256 index) {
        index = users.length;
        
        users.push(User({
            name: name,
            age: age,
            isActive: true
        }));

        emit UserRegistered(index, name, age);
    }

    /**
     * @notice 获取用户信息
     * @param index 用户索引
     * @return name 用户名
     * @return age 年龄
     * @return isActive 是否激活
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
     * @notice 获取用户数量
     */
    function getUserCount() external view returns (uint256) {
        return users.length;
    }

    /**
     * @notice 获取合约版本
     */
    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }

    // ============ Admin Functions ============
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
