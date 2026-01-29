// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/ArrayUserRegistryV1.sol";
import "../src/ArrayUserRegistryV2.sol";

/**
 * @title ArrayStructUpgradeTest
 * @notice 测试动态数组中结构体字段扩展导致的存储布局问题
 * 
 * ============================================================================
 * 📚 核心结论
 * ============================================================================
 * 
 * 在可升级合约中，对于 User[] 这样的动态数组：
 * ❌ 不能在 User 结构体中添加新字段！
 * 
 * 原因：
 * 1. 动态数组的元素是连续存储的
 * 2. 每个 User 占用固定数量的 slot
 * 3. 添加字段会改变每个 User 的大小
 * 4. 导致 User[1], User[2], ... 的位置计算全部错误
 * 
 * 与 mapping 的区别：
 * - mapping 中每个元素有独立的基础 slot（通过 keccak256 计算）
 * - 可以在 mapping 值的结构体末尾添加字段
 * - 数组不行，因为元素是连续排列的
 * 
 */
contract ArrayStructUpgradeTest is Test {
    ArrayUserRegistryV1 v1Impl;
    ArrayUserRegistryV2 v2Impl;
    ERC1967Proxy proxy;
    ArrayUserRegistryV1 proxyAsV1;
    ArrayUserRegistryV2 proxyAsV2;
    
    address owner = address(this);
    
    function setUp() public {
        // 部署 V1 实现
        v1Impl = new ArrayUserRegistryV1();
        
        // 部署代理，指向 V1
        bytes memory initData = abi.encodeWithSelector(
            ArrayUserRegistryV1.initialize.selector,
            owner
        );
        proxy = new ERC1967Proxy(address(v1Impl), initData);
        proxyAsV1 = ArrayUserRegistryV1(address(proxy));
    }

    /**
     * @notice 验证 V1 基本功能正常
     */
    function test_V1_BasicFunctionality() public {
        console.log("========================================");
        console.log("TEST: V1 Basic Functionality");
        console.log("========================================");
        
        // 注册两个用户
        proxyAsV1.registerUser("Alice", 25);
        proxyAsV1.registerUser("Bob", 30);
        
        // 验证用户数据
        (string memory name0, uint256 age0, bool active0) = proxyAsV1.getUser(0);
        (string memory name1, uint256 age1, bool active1) = proxyAsV1.getUser(1);
        
        console.log("User[0]: name=%s, age=%d, active=%s", name0, age0, active0 ? "true" : "false");
        console.log("User[1]: name=%s, age=%d, active=%s", name1, age1, active1 ? "true" : "false");
        
        assertEq(name0, "Alice");
        assertEq(age0, 25);
        assertTrue(active0);
        
        assertEq(name1, "Bob");
        assertEq(age1, 30);
        assertTrue(active1);
        
        assertEq(proxyAsV1.getUserCount(), 2);
        
        console.log("");
        console.log("V1 functionality works correctly!");
    }

    /**
     * @notice 🔴 核心测试：验证数组中结构体字段扩展导致数据错乱
     * @dev 这个测试展示了为什么不能在数组的结构体中添加新字段
     */
    function test_ArrayStructExpansion_CausesDataCorruption() public {
        console.log("========================================");
        console.log("TEST: Array Struct Expansion Causes Data Corruption");
        console.log("========================================");
        
        // Step 1: 在 V1 中注册多个用户
        console.log("");
        console.log("[Step 1] Register users in V1");
        proxyAsV1.registerUser("Alice", 25);
        proxyAsV1.registerUser("Bob", 30);
        proxyAsV1.registerUser("Charlie", 35);
        
        console.log("  Registered 3 users: Alice(25), Bob(30), Charlie(35)");
        
        // 记录 V1 的数据
        (string memory v1Name0, uint256 v1Age0, bool v1Active0) = proxyAsV1.getUser(0);
        (string memory v1Name1, uint256 v1Age1, bool v1Active1) = proxyAsV1.getUser(1);
        (string memory v1Name2, uint256 v1Age2, bool v1Active2) = proxyAsV1.getUser(2);
        
        console.log("");
        console.log("[V1 Data Before Upgrade]");
        console.log("  User[0]: name=%s, age=%d, active=%s", v1Name0, v1Age0, v1Active0 ? "true" : "false");
        console.log("  User[1]: name=%s, age=%d, active=%s", v1Name1, v1Age1, v1Active1 ? "true" : "false");
        console.log("  User[2]: name=%s, age=%d, active=%s", v1Name2, v1Age2, v1Active2 ? "true" : "false");
        
        // Step 2: 升级到 V2（结构体添加了新字段）
        console.log("");
        console.log("[Step 2] Upgrade to V2 (struct has 2 new fields)");
        v2Impl = new ArrayUserRegistryV2();
        proxyAsV1.upgradeToAndCall(
            address(v2Impl),
            abi.encodeWithSelector(ArrayUserRegistryV2.initializeV2.selector)
        );
        proxyAsV2 = ArrayUserRegistryV2(address(proxy));
        
        console.log("  Upgrade completed!");
        console.log("  V2 User struct has 5 slots (was 3 in V1)");
        
        // Step 3: 读取升级后的数据 - 这里会出现问题！
        console.log("");
        console.log("[Step 3] Read data after upgrade - DATA CORRUPTION!");
        
        // User[0] 可能还是正确的（因为它是第一个）
        (string memory v2Name0, uint256 v2Age0, bool v2Active0) = proxyAsV2.getUser(0);
        console.log("  User[0]: name=%s, age=%d, active=%s", v2Name0, v2Age0, v2Active0 ? "true" : "false");
        
        // User[1] 的数据会错乱！
        // V2 认为 User[1] 从 H+5 开始，但实际 V1 数据中 User[1] 从 H+3 开始
        console.log("");
        console.log("  Attempting to read User[1]...");
        console.log("  V2 expects User[1] at slot H+5, but V1 stored it at H+3!");
        
        // 这里可能会 revert 或返回乱码数据
        try proxyAsV2.getUser(1) returns (string memory name, uint256 age, bool active) {
            console.log("  User[1]: name=%s, age=%d, active=%s", name, age, active ? "true" : "false");
            
            // 验证数据是否被破坏
            bool dataCorrupted = (
                keccak256(bytes(name)) != keccak256(bytes("Bob")) ||
                age != 30
            );
            
            if (dataCorrupted) {
                console.log("");
                console.log("  !!! DATA CORRUPTED !!!");
                console.log("  Expected: name=Bob, age=30");
                console.log("  V2 reads wrong data because of storage layout shift!");
            }
        } catch {
            console.log("  !!! REVERT when reading User[1] !!!");
            console.log("  Storage layout is completely broken!");
        }
        
        // Step 4: 尝试读取完整的 V2 用户数据
        console.log("");
        console.log("[Step 4] Try to read full user data (with new fields)");
        
        try proxyAsV2.getUserFull(0) returns (
            string memory name,
            uint256 age,
            bool active,
            string memory email,
            uint256 score
        ) {
            console.log("  User[0] full data:");
            console.log("    name: %s", name);
            console.log("    age: %d", age);
            console.log("    active: %s", active ? "true" : "false");
            console.log("    email: %s", bytes(email).length > 0 ? email : "(empty)");
            console.log("    score: %d", score);
            
            // email 和 score 字段实际上会读取到 User[1] 的数据！
            if (score != 0 || bytes(email).length > 0) {
                console.log("");
                console.log("  !!! NEW FIELDS CONTAIN CORRUPTED DATA !!!");
                console.log("  email/score slots actually contain User[1]'s data!");
            }
        } catch {
            console.log("  !!! REVERT when reading getUserFull !!!");
        }
        
        console.log("");
        console.log("========================================");
        console.log("CONCLUSION: Cannot add fields to struct in array!");
        console.log("========================================");
    }

    /**
     * @notice 通过存储槽直接观察数据布局
     */
    function test_ObserveStorageLayout() public {
        console.log("========================================");
        console.log("TEST: Observe Storage Layout");
        console.log("========================================");
        
        // 注册用户
        proxyAsV1.registerUser("Alice", 25);
        proxyAsV1.registerUser("Bob", 30);
        
        // 计算数组元素的起始位置
        // users 数组在 slot 0，元素存储在 keccak256(0)
        bytes32 arrayBaseSlot = keccak256(abi.encode(uint256(0)));
        
        console.log("");
        console.log("[V1 Storage Layout]");
        console.log("  Array length slot: 0");
        console.log("  Array base slot (H): %s", vm.toString(arrayBaseSlot));
        
        // V1: 每个 User 占用 3 个 slot
        console.log("");
        console.log("  V1 User struct size: 3 slots");
        console.log("");
        console.log("  User[0] (H+0 to H+2):");
        bytes32 slot0 = vm.load(address(proxy), arrayBaseSlot);
        bytes32 slot1 = vm.load(address(proxy), bytes32(uint256(arrayBaseSlot) + 1));
        bytes32 slot2 = vm.load(address(proxy), bytes32(uint256(arrayBaseSlot) + 2));
        console.log("    Slot H+0 (name ptr): %s", vm.toString(slot0));
        console.log("    Slot H+1 (age=25):   %s", vm.toString(slot1));
        console.log("    Slot H+2 (active):   %s", vm.toString(slot2));
        
        console.log("");
        console.log("  User[1] (H+3 to H+5):");
        bytes32 slot3 = vm.load(address(proxy), bytes32(uint256(arrayBaseSlot) + 3));
        bytes32 slot4 = vm.load(address(proxy), bytes32(uint256(arrayBaseSlot) + 4));
        bytes32 slot5 = vm.load(address(proxy), bytes32(uint256(arrayBaseSlot) + 5));
        console.log("    Slot H+3 (name ptr): %s", vm.toString(slot3));
        console.log("    Slot H+4 (age=30):   %s", vm.toString(slot4));
        console.log("    Slot H+5 (active):   %s", vm.toString(slot5));
        
        // 验证 age 存储正确
        assertEq(uint256(slot1), 25, "User[0].age should be 25");
        assertEq(uint256(slot4), 30, "User[1].age should be 30");
        
        // 升级到 V2
        console.log("");
        console.log("========================================");
        console.log("After Upgrade to V2:");
        console.log("========================================");
        
        v2Impl = new ArrayUserRegistryV2();
        proxyAsV1.upgradeToAndCall(
            address(v2Impl),
            abi.encodeWithSelector(ArrayUserRegistryV2.initializeV2.selector)
        );
        proxyAsV2 = ArrayUserRegistryV2(address(proxy));
        
        console.log("");
        console.log("  V2 User struct size: 5 slots");
        console.log("");
        console.log("  V2 EXPECTS User[0] at H+0 to H+4:");
        console.log("    Slot H+0: name");
        console.log("    Slot H+1: age");
        console.log("    Slot H+2: isActive");
        console.log("    Slot H+3: email (NEW)");
        console.log("    Slot H+4: score (NEW)");
        console.log("");
        console.log("  V2 EXPECTS User[1] at H+5 to H+9:");
        console.log("    Slot H+5: name");
        console.log("    Slot H+6: age");
        console.log("    Slot H+7: isActive");
        console.log("    ...");
        
        console.log("");
        console.log("  BUT ACTUAL DATA (from V1) is:");
        console.log("    Slot H+3: User[1].name   <- V2 thinks this is User[0].email!");
        console.log("    Slot H+4: User[1].age=30 <- V2 thinks this is User[0].score!");
        console.log("    Slot H+5: User[1].active <- V2 thinks this is User[1].name!");
        
        // 验证 V2 会把 User[1] 的 age 误读为 User[0] 的 score
        (, , , , uint256 corruptedScore) = proxyAsV2.getUserFull(0);
        console.log("");
        console.log("  Verification:");
        console.log("    proxyAsV2.getUserFull(0).score = %d", corruptedScore);
        console.log("    This is actually User[1].age from V1 = 30!");
        
        // 这证明了数据错乱
        assertEq(corruptedScore, 30, "V2 reads User[1].age as User[0].score - CORRUPTED!");
        
        console.log("");
        console.log("========================================");
        console.log("STORAGE LAYOUT CORRUPTION VERIFIED!");
        console.log("========================================");
    }

    /**
     * @notice 对比：mapping 中的结构体 vs 数组中的结构体
     */
    function test_CompareArrayVsMapping() public {
        console.log("========================================");
        console.log("COMPARISON: Array vs Mapping for Struct Upgrade");
        console.log("========================================");
        
        console.log("");
        console.log("[Mapping Storage Layout]");
        console.log("  mapping(uint => User) users;");
        console.log("");
        console.log("  users[0] location: keccak256(0, slot)");
        console.log("  users[1] location: keccak256(1, slot) <- INDEPENDENT!");
        console.log("  users[2] location: keccak256(2, slot) <- INDEPENDENT!");
        console.log("");
        console.log("  Each user has its own base slot calculated by keccak256.");
        console.log("  Adding fields to struct only affects slots AFTER the base.");
        console.log("  Other users are NOT affected!");
        console.log("");
        console.log("  => CAN add fields at the END of struct in mapping.");
        
        console.log("");
        console.log("----------------------------------------");
        
        console.log("");
        console.log("[Array Storage Layout]");
        console.log("  User[] users;");
        console.log("");
        console.log("  users[0] location: H + 0 * structSize");
        console.log("  users[1] location: H + 1 * structSize <- DEPENDS ON STRUCT SIZE!");
        console.log("  users[2] location: H + 2 * structSize <- DEPENDS ON STRUCT SIZE!");
        console.log("");
        console.log("  All users are stored CONTIGUOUSLY!");
        console.log("  If struct size changes, ALL users[i>0] locations shift!");
        console.log("");
        console.log("  => CANNOT add fields to struct in array!");
        
        console.log("");
        console.log("========================================");
        console.log("RECOMMENDATION:");
        console.log("  For upgradeable contracts with structs that may change:");
        console.log("  - Use mapping instead of array");
        console.log("  - Or use a separate mapping for new fields");
        console.log("  - Or redesign with ERC-7201 namespaced storage");
        console.log("========================================");
    }
}
