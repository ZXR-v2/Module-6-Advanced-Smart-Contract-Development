// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/UserRegistryV1.sol";
import "../src/UserRegistryV2.sol";
import "../src/UserRegistryV2Bad.sol";

/**
 * @title StructUpgradeTest
 * @notice 测试可升级合约中 mapping 里结构体扩展的问题
 * 
 * ============================================================================
 * 📚 测试目标
 * ============================================================================
 * 
 * 1. ✅ 验证在结构体末尾添加字段是安全的
 * 2. ❌ 验证在结构体开头添加字段会导致数据损坏
 * 
 */
contract StructUpgradeTest is Test {
    // 合约实例
    UserRegistryV1 public v1Impl;
    UserRegistryV2 public v2Impl;
    UserRegistryV2Bad public v2BadImpl;
    
    // 代理合约
    ERC1967Proxy public proxy;
    
    // 代理地址的接口
    UserRegistryV1 public proxyAsV1;
    UserRegistryV2 public proxyAsV2;
    UserRegistryV2Bad public proxyAsV2Bad;
    
    address public owner = address(this);

    function setUp() public {
        // 部署 V1 实现合约
        v1Impl = new UserRegistryV1();
        
        // 部署代理合约，指向 V1 实现
        bytes memory initData = abi.encodeWithSelector(
            UserRegistryV1.initialize.selector,
            owner
        );
        proxy = new ERC1967Proxy(address(v1Impl), initData);
        
        // 通过代理访问 V1
        proxyAsV1 = UserRegistryV1(address(proxy));
    }

    /**
     * ============================================================================
     * ✅ 测试 1: 验证在结构体末尾添加字段是安全的
     * ============================================================================
     */
    function test_UpgradeWithFieldsAtEnd_DataPreserved() public {
        console.log("");
        console.log("========================================");
        console.log("TEST: Upgrade with fields at END");
        console.log("========================================");
        
        // ========== Step 1: 在 V1 中创建用户数据 ==========
        console.log("");
        console.log("[V1] Creating users...");
        
        uint256 userId1 = proxyAsV1.registerUser("Alice", 25);
        uint256 userId2 = proxyAsV1.registerUser("Bob", 30);
        
        // 验证 V1 数据
        (string memory name1, uint256 age1, bool active1) = proxyAsV1.getUser(userId1);
        (string memory name2, uint256 age2, bool active2) = proxyAsV1.getUser(userId2);
        
        console.log("[V1] User 1: name=%s, age=%d, active=%s", name1, age1, active1 ? "true" : "false");
        console.log("[V1] User 2: name=%s, age=%d, active=%s", name2, age2, active2 ? "true" : "false");
        console.log("[V1] Version:", proxyAsV1.version());
        
        assertEq(name1, "Alice");
        assertEq(age1, 25);
        assertTrue(active1);
        assertEq(name2, "Bob");
        assertEq(age2, 30);
        assertTrue(active2);
        
        // ========== Step 2: 升级到 V2 (末尾添加字段) ==========
        console.log("");
        console.log("[UPGRADE] Upgrading to V2 (fields added at END)...");
        
        v2Impl = new UserRegistryV2();
        
        // 执行升级
        bytes memory upgradeData = abi.encodeWithSelector(
            UserRegistryV2.initializeV2.selector
        );
        proxyAsV1.upgradeToAndCall(address(v2Impl), upgradeData);
        
        // 通过 V2 接口访问
        proxyAsV2 = UserRegistryV2(address(proxy));
        
        console.log("[V2] Upgrade complete!");
        console.log("[V2] Version:", proxyAsV2.version());
        
        // ========== Step 3: 验证原有数据是否保持完整 ==========
        console.log("");
        console.log("[V2] Verifying original data is preserved...");
        
        (string memory name1After, uint256 age1After, bool active1After) = proxyAsV2.getUser(userId1);
        (string memory name2After, uint256 age2After, bool active2After) = proxyAsV2.getUser(userId2);
        
        console.log("[V2] User 1: name=%s, age=%d, active=%s", name1After, age1After, active1After ? "true" : "false");
        console.log("[V2] User 2: name=%s, age=%d, active=%s", name2After, age2After, active2After ? "true" : "false");
        
        // ✅ 验证原有字段数据不变
        assertEq(name1After, "Alice", "User 1 name should be preserved");
        assertEq(age1After, 25, "User 1 age should be preserved");
        assertTrue(active1After, "User 1 active should be preserved");
        assertEq(name2After, "Bob", "User 2 name should be preserved");
        assertEq(age2After, 30, "User 2 age should be preserved");
        assertTrue(active2After, "User 2 active should be preserved");
        
        console.log("");
        console.log("[V2] PASS: Original data preserved!");
        
        // ========== Step 4: 验证新字段默认值 ==========
        console.log("");
        console.log("[V2] Checking new fields have default values...");
        
        (,,, string memory email1, uint256 score1) = proxyAsV2.getUserFull(userId1);
        (,,, string memory email2, uint256 score2) = proxyAsV2.getUserFull(userId2);
        
        console.log("[V2] User 1 new fields: email='%s', score=%d", email1, score1);
        console.log("[V2] User 2 new fields: email='%s', score=%d", email2, score2);
        
        // 新字段应该是默认值
        assertEq(email1, "", "New email field should be empty string");
        assertEq(score1, 0, "New score field should be 0");
        assertEq(email2, "", "New email field should be empty string");
        assertEq(score2, 0, "New score field should be 0");
        
        console.log("[V2] PASS: New fields have default values!");
        
        // ========== Step 5: 验证可以更新新字段 ==========
        console.log("");
        console.log("[V2] Updating new fields...");
        
        proxyAsV2.updateEmail(userId1, "alice@example.com");
        proxyAsV2.addScore(userId1, 100);
        
        (,,, string memory email1Updated, uint256 score1Updated) = proxyAsV2.getUserFull(userId1);
        
        console.log("[V2] User 1 after update: email='%s', score=%d", email1Updated, score1Updated);
        
        assertEq(email1Updated, "alice@example.com", "Email should be updated");
        assertEq(score1Updated, 100, "Score should be updated");
        
        // 验证原有字段仍然正确
        (string memory name1Final, uint256 age1Final, bool active1Final) = proxyAsV2.getUser(userId1);
        assertEq(name1Final, "Alice", "Name should still be correct");
        assertEq(age1Final, 25, "Age should still be correct");
        assertTrue(active1Final, "Active should still be correct");
        
        console.log("[V2] PASS: New fields can be updated!");
        
        console.log("");
        console.log("========================================");
        console.log("CONCLUSION: Adding fields at END is SAFE!");
        console.log("========================================");
    }

    /**
     * ============================================================================
     * ❌ 测试 2: 验证在结构体开头添加字段会导致数据损坏
     * ============================================================================
     */
    function test_UpgradeWithFieldsAtBeginning_DataCorrupted() public {
        console.log("");
        console.log("========================================");
        console.log("TEST: Upgrade with fields at BEGINNING");
        console.log("========================================");
        
        // ========== Step 1: 在 V1 中创建用户数据 ==========
        console.log("");
        console.log("[V1] Creating user...");
        
        uint256 userId = proxyAsV1.registerUser("Alice", 25);
        
        (string memory name, uint256 age, bool active) = proxyAsV1.getUser(userId);
        console.log("[V1] User: name=%s, age=%d, active=%s", name, age, active ? "true" : "false");
        
        assertEq(name, "Alice");
        assertEq(age, 25);
        assertTrue(active);
        
        // ========== Step 2: 升级到 V2Bad (开头添加字段) ==========
        console.log("");
        console.log("[UPGRADE] Upgrading to V2Bad (field added at BEGINNING)...");
        
        v2BadImpl = new UserRegistryV2Bad();
        
        bytes memory upgradeData = abi.encodeWithSelector(
            UserRegistryV2Bad.initializeV2.selector
        );
        proxyAsV1.upgradeToAndCall(address(v2BadImpl), upgradeData);
        
        proxyAsV2Bad = UserRegistryV2Bad(address(proxy));
        
        console.log("[V2Bad] Upgrade complete!");
        console.log("[V2Bad] Version:", proxyAsV2Bad.version());
        
        // ========== Step 3: 观察数据损坏情况 ==========
        console.log("");
        console.log("[V2Bad] Reading data (will be CORRUPTED)...");
        
        // 读取新增的 id 字段 - 会读到原来 name 的数据（解释为 uint256）
        // 这个调用不会 panic，因为 uint256 可以存储任何 32 字节数据
        uint256 corruptedId = proxyAsV2Bad.getUserId(userId);
        console.log("[V2Bad] 'id' field (actually old name data):", corruptedId);
        console.log("[V2Bad] Note: The 'id' field now contains garbage (old name bytes as uint256)");
        
        // ❌ 尝试读取 name 会导致 panic，因为存储数据被错误解释
        // 必须使用低级调用来捕获 panic，否则测试会直接失败
        console.log("");
        console.log("[V2Bad] Attempting to read user data with low-level call...");
        console.log("[V2Bad] Expected: Revert due to storage byte array incorrectly encoded");
        
        // 使用低级调用来避免 panic 传播
        (bool success, ) = address(proxyAsV2Bad).staticcall(
            abi.encodeWithSelector(UserRegistryV2Bad.getUser.selector, userId)
        );
        
        console.log("[V2Bad] Call success: %s", success ? "true" : "false");
        
        if (!success) {
            console.log("[V2Bad] CONFIRMED: Call reverted - data is corrupted!");
        }
        
        console.log("");
        console.log("========================================");
        console.log("CONCLUSION: Adding fields at BEGINNING causes PANIC!");
        console.log("  - Storage data becomes unreadable");
        console.log("  - Contract functionality is broken");
        console.log("  - This is a CRITICAL bug!");
        console.log("========================================");
        
        // 验证调用确实失败了
        assertFalse(success, "Call should fail when reading corrupted storage");
    }

    /**
     * ============================================================================
     * 📊 测试 3: 直接比较存储布局
     * ============================================================================
     */
    function test_StorageLayoutComparison() public {
        console.log("");
        console.log("========================================");
        console.log("TEST: Storage Layout Comparison");
        console.log("========================================");
        
        // 创建用户
        uint256 userId = proxyAsV1.registerUser("Test", 42);
        
        // 读取 users mapping 中 userId 对应的存储槽
        // mapping 的值存储在 keccak256(key . slot) 位置
        // users 在 slot 1
        bytes32 baseSlot = keccak256(abi.encode(userId, uint256(1)));
        
        console.log("");
        console.log("[Storage] Base slot for users[%d]:", userId);
        console.log("  keccak256(userId . mappingSlot) = %s", vm.toString(baseSlot));
        
        // 读取存储槽的值
        bytes32 slot0Value = vm.load(address(proxy), baseSlot);
        bytes32 slot1Value = vm.load(address(proxy), bytes32(uint256(baseSlot) + 1));
        bytes32 slot2Value = vm.load(address(proxy), bytes32(uint256(baseSlot) + 2));
        bytes32 slot3Value = vm.load(address(proxy), bytes32(uint256(baseSlot) + 3));
        
        console.log("");
        console.log("[V1 Storage Layout]");
        console.log("  Slot S+0 (name pointer): %s", vm.toString(slot0Value));
        console.log("  Slot S+1 (age=42): %s", vm.toString(slot1Value));
        console.log("  Slot S+2 (isActive=true): %s", vm.toString(slot2Value));
        console.log("  Slot S+3 (empty): %s", vm.toString(slot3Value));
        
        // 验证 age 存储在正确的位置
        assertEq(uint256(slot1Value), 42, "Age should be stored at slot S+1");
        
        // 升级到 V2
        v2Impl = new UserRegistryV2();
        proxyAsV1.upgradeToAndCall(
            address(v2Impl), 
            abi.encodeWithSelector(UserRegistryV2.initializeV2.selector)
        );
        proxyAsV2 = UserRegistryV2(address(proxy));
        
        // 读取升级后的存储
        bytes32 slot0After = vm.load(address(proxy), baseSlot);
        bytes32 slot1After = vm.load(address(proxy), bytes32(uint256(baseSlot) + 1));
        bytes32 slot2After = vm.load(address(proxy), bytes32(uint256(baseSlot) + 2));
        bytes32 slot3After = vm.load(address(proxy), bytes32(uint256(baseSlot) + 3));
        bytes32 slot4After = vm.load(address(proxy), bytes32(uint256(baseSlot) + 4));
        
        console.log("");
        console.log("[V2 Storage Layout]");
        console.log("  Slot S+0 (name pointer): %s", vm.toString(slot0After));
        console.log("  Slot S+1 (age=42): %s", vm.toString(slot1After));
        console.log("  Slot S+2 (isActive=true): %s", vm.toString(slot2After));
        console.log("  Slot S+3 (email - new, empty): %s", vm.toString(slot3After));
        console.log("  Slot S+4 (score - new, 0): %s", vm.toString(slot4After));
        
        // 验证原有数据位置没变
        assertEq(slot0After, slot0Value, "Name slot should be unchanged");
        assertEq(slot1After, slot1Value, "Age slot should be unchanged");
        assertEq(slot2After, slot2Value, "IsActive slot should be unchanged");
        
        // 验证新字段是默认值
        assertEq(uint256(slot4After), 0, "New score field should be 0");
        
        console.log("");
        console.log("========================================");
        console.log("CONCLUSION: Storage slots preserved after upgrade!");
        console.log("========================================");
    }
}
