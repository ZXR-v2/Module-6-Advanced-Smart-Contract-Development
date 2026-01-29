# Practice 8: 可升级合约中结构体扩展测试（Mapping vs Array）

## 问题

在编写可升级合约时：

1. 如果第一个版本逻辑实现合约中有一个 `mapping(uint => User) users`，其中 `User` 是一个结构体类型，请问在第二个版本的逻辑实现合约中，可否在 `User` 结构体里添加一个变量？
2. 如果第一个版本逻辑实现合约中有一个 `User[] users`（动态数组），第二个版本是否还能在 `User` 结构体里添加一个变量？

## 结论

### ✅ Mapping 中可以在结构体**末尾**添加新字段

这是安全的升级方式。原因如下：

1. **Mapping 的值存储在独立的 Hash 空间**：每个 key 的值存储在 `keccak256(key . slot)` 计算出的位置
2. **结构体成员按顺序存储**：新成员添加在末尾会使用新的 storage slot
3. **原有数据位置不变**：原来的字段仍然在相同的 slot 位置
4. **新字段初始值为默认值**：新添加的字段初始值为 0、空字符串等

```
升级前 User { name, age, isActive }:
┌────────────────────────────────────────┐
│ Slot S:   name (string)                │
│ Slot S+1: age (uint256)                │
│ Slot S+2: isActive (bool)              │
└────────────────────────────────────────┘

升级后 User { name, age, isActive, email, score }:
┌────────────────────────────────────────┐
│ Slot S:   name (string)     ← 不变     │
│ Slot S+1: age (uint256)     ← 不变     │
│ Slot S+2: isActive (bool)   ← 不变     │
│ Slot S+3: email (string)    ← 新增     │
│ Slot S+4: score (uint256)   ← 新增     │
└────────────────────────────────────────┘
```

### ❌ Mapping 中不能在结构体**开头或中间**添加新字段

这会导致存储布局损坏！原因：

1. **所有后续字段位置偏移**：在开头添加字段会导致所有原有字段的 slot 偏移
2. **数据被错误解释**：原来的 `name` 数据会被解释为新的 `id` 字段
3. **可能导致 Panic**：尝试读取字符串数据时会因为存储格式错误而 panic

```
V1 存储的数据:
┌────────────────────────────────────────┐
│ Slot S:   "Alice" (name)               │
│ Slot S+1: 25 (age)                     │
│ Slot S+2: true (isActive)              │
└────────────────────────────────────────┘

V2Bad 读取时的解释 (在开头添加了 id):
┌────────────────────────────────────────┐
│ Slot S:   "Alice" → id ❌ 乱码!         │
│ Slot S+1: 25 → name 指针 ❌ 错误!       │
│ Slot S+2: true → age ❌ 变成 1!        │
│ Slot S+3: ??? → isActive ❌ 读到 0!    │
└────────────────────────────────────────┘
```

### ❌ Array 中不能在结构体添加新字段（即使在末尾）

动态数组的元素是**连续存储**的，结构体大小一旦改变，后面的元素位置会整体偏移，导致数据错乱。

```
V1: User 占用 3 个 slot
H+0: users[0].name
H+1: users[0].age
H+2: users[0].isActive
H+3: users[1].name  ← User[1] 紧接着 User[0]
H+4: users[1].age
H+5: users[1].isActive

V2: User 占用 5 个 slot（新增 email, score）
H+0: users[0].name
H+1: users[0].age
H+2: users[0].isActive
H+3: users[0].email  ← 实际上是 users[1].name（错乱）
H+4: users[0].score  ← 实际上是 users[1].age（错乱）
H+5: users[1].name   ← 实际上是 users[1].isActive（错乱）
```

结论：**数组中的结构体不能新增字段**，否则存储布局会被破坏。

## 测试验证（建议在 WSL 中运行）

运行测试（WSL）：

```bash
forge test -vvv
```

### 测试结果

```
[PASS] test_UpgradeWithFieldsAtEnd_DataPreserved()
  - V1 创建用户: Alice, 25
  - 升级到 V2 (末尾添加 email, score)
  - 验证原数据保持完整 ✅
  - 验证新字段默认值为空 ✅
  - 验证可以更新新字段 ✅

[PASS] test_UpgradeWithFieldsAtBeginning_DataCorrupted()
  - V1 创建用户: Alice, 25
  - 升级到 V2Bad (开头添加 id)
  - 读取 id 字段得到乱码: 2.959e76 ❌
  - 读取 name 字段导致 PANIC ❌

[PASS] test_StorageLayoutComparison()
  - 直接读取 storage slots 验证数据位置
  - 升级前后 slot 位置不变 ✅

[PASS] test_ArrayStructExpansion_CausesDataCorruption()
  - V1 注册 3 个用户
  - 升级到 V2（在数组结构体末尾添加字段）
  - 读取 User[1] 数据错乱 ❌
  - 新字段读到了 User[1] 的旧数据 ❌

[PASS] test_ObserveStorageLayout()
  - 直接读取数组的 storage slots
  - 验证 H+3/H+4 被 V2 当作新字段读取
```

## 最佳实践总结

| 操作 | 是否安全 | 说明 |
|------|----------|------|
| 在结构体末尾添加字段 | ✅ 安全（仅 Mapping） | 新字段使用新 slot |
| 在结构体开头添加字段 | ❌ 危险 | 所有字段位置偏移 |
| 在结构体中间添加字段 | ❌ 危险 | 后续字段位置偏移 |
| 删除结构体字段 | ❌ 危险 | 后续字段位置偏移 |
| 更改字段类型 | ❌ 危险 | 数据解释方式改变 |
| 重新排序字段 | ❌ 危险 | 字段位置改变 |
| 在数组结构体中添加字段 | ❌ 危险 | 数组元素连续存储 |

## 文件结构

```
practice-8-tests/
├── src/
│   ├── UserRegistryV1.sol      # V1: User { name, age, isActive }
│   ├── UserRegistryV2.sol      # V2: User { name, age, isActive, email, score } ✅
│   ├── UserRegistryV2Bad.sol   # V2Bad: User { id, name, age, isActive } ❌
│   ├── ArrayUserRegistryV1.sol # V1: User[] 数组结构体
│   └── ArrayUserRegistryV2.sol # V2: 在数组结构体末尾添加字段 ❌
├── test/
│   ├── StructUpgrade.t.sol     # Mapping 结构体升级测试
│   └── ArrayStructUpgrade.t.sol# Array 结构体升级测试
└── README.md                    # 本文件
```
