// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title UserRegistryV1
 * @notice 可升级用户注册合约 - 版本 1
 * @dev 用于验证 mapping 中结构体扩展的问题
 * 
 * ============================================================================
 * 📐 存储布局
 * ============================================================================
 * 
 *   ┌─────────────────────────────────────────┐
 *   │ Slot 0:  nextUserId                     │
 *   │ Slot 1:  users mapping                  │
 *   │ Slot 2-49: __gap (预留)                  │
 *   └─────────────────────────────────────────┘
 * 
 *   对于 users[1] 的存储位置 = keccak256(1 . 1):
 *   ┌─────────────────────────────────────────┐
 *   │ Slot S:   name (字符串指针)              │
 *   │ Slot S+1: age (uint256)                 │
 *   │ Slot S+2: isActive (bool)               │
 *   └─────────────────────────────────────────┘
 * 
 */
contract UserRegistryV1 is 
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    // ============ Structs ============
    /// @notice V1 版本的 User 结构体
    struct User {
        string name;      // 用户名
        uint256 age;      // 年龄
        bool isActive;    // 是否激活
    }

    // ============ State Variables ============
    /// @notice 下一个用户 ID
    uint256 public nextUserId;                    // Slot 0
    
    /// @notice 用户 ID => User 信息
    mapping(uint256 => User) public users;        // Slot 1

    // ============ Events ============
    event UserRegistered(uint256 indexed userId, string name, uint256 age);
    event UserUpdated(uint256 indexed userId, string name, uint256 age);

    // ============ Storage Gap ============
    /// @dev 为未来升级预留存储空间
    uint256[48] private __gap;                    // Slot 2-49

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
        nextUserId = 1;
    }

    // ============ User Functions ============

    /**
     * @notice 注册新用户
     * @param name 用户名
     * @param age 年龄
     * @return userId 新用户的 ID
     */
    function registerUser(string calldata name, uint256 age) external returns (uint256 userId) {
        userId = nextUserId++;
        
        users[userId] = User({
            name: name,
            age: age,
            isActive: true
        });

        emit UserRegistered(userId, name, age);
    }

    /**
     * @notice 获取用户信息
     * @param userId 用户 ID
     * @return name 用户名
     * @return age 年龄
     * @return isActive 是否激活
     */
    function getUser(uint256 userId) external view returns (
        string memory name,
        uint256 age,
        bool isActive
    ) {
    // storage 表示这个局部变量是指向合约存储（persistent storage）的引用（指针），所以
    // user.xxx 的修改会直接写回到 users[userId] 的存储槽，持久化到链上。
    // 如果用 memory，会把 users[userId] 的数据拷贝到内存，修改只影响拷贝，不会持久化。
    // 对于复杂类型（struct、array、mapping）的局部变量，编译器要求显式指定数据位置（storage 或 memory）。
    // 另外，使用 storage 通常比把整个 struct 拷贝到 memory 更省 gas（尤其 struct 很大或只读少量字段时也通常更高效）。
        User storage user = users[userId];
        return (user.name, user.age, user.isActive);
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
