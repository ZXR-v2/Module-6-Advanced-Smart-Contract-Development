# 实战 3 & 4 - EVM 存储布局

## 实战 3：使用内联汇编读取和修改 Owner

**题目链接**: https://decert.me/challenge/163c68ab-8adf-4377-a1c2-b5d0132edc69

**答案**: [MyWallet.sol](./MyWallet.sol)

---

## 实战 4：利用存储布局读取私有变量

**题目链接**: https://decert.me/quests/b0782759-4995-4bcb-85c2-2af749f0fde9

使用 Viem 的 `getStorageAt` 从链上读取 `_locks` 数组中的所有元素。

### 文件说明

| 文件 | 说明 |
|------|------|
| `esRNT.sol` | 待读取的合约源码 |
| `readLocks.ts` | Viem 读取脚本 |
| `package.json` | Node 依赖配置 |

---

## 运行步骤

### 1. 启动 Anvil（终端 1）

```bash
anvil
```

保持运行，默认 RPC: `http://127.0.0.1:8545`

### 2. 部署 esRNT 合约（终端 2）

```bash
cd practice-3-4-solutuions

forge create esRNT.sol:esRNT \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

部署成功后记录合约地址，如：
```
Deployed to: 0x5FbDB2315678afecb367f032d93F642f64180aa3
```

> 如果地址不同，修改 `readLocks.ts` 第 5 行的 `CONTRACT_ADDRESS`

### 3. 安装依赖并运行脚本

```bash
cd practice-3-4-solutuions
npm install
npm run read
```

---

## 预期输出

```
_locks 数组长度: 11

locks[0]: user: 0x0000000000000000000000000000000000000001, startTime: 3455678902, amount: 1000000000000000000
locks[1]: user: 0x0000000000000000000000000000000000000002, startTime: 3455678901, amount: 2000000000000000000
locks[2]: user: 0x0000000000000000000000000000000000000003, startTime: 3455678900, amount: 3000000000000000000
...
locks[10]: user: 0x000000000000000000000000000000000000000b, startTime: 3455678892, amount: 11000000000000000000
```

---

## 存储布局说明

### esRNT 合约结构

```solidity
struct LockInfo {
    address user;      // 20 bytes
    uint64 startTime;  // 8 bytes
    uint256 amount;    // 32 bytes
}

LockInfo[] private _locks;  // slot 0
```

### 存储布局

- **Slot 0**: 存储数组长度
- **数组元素起始位置**: `keccak256(abi.encode(0))`
- **每个 LockInfo 占用 2 个 slots**:
  - **Slot N**: `user`(20B) + `startTime`(8B) 打包在一起（共 28B，低位对齐）
  - **Slot N+1**: `amount`(32B)

### 读取逻辑

```typescript
// 1. 读取长度
const length = await getStorageAt(contract, slot(0));

// 2. 计算起始位置
const baseSlot = keccak256(abi.encode(0));

// 3. 遍历读取
for (let i = 0; i < length; i++) {
  const slot0 = baseSlot + i * 2;     // user + startTime
  const slot1 = baseSlot + i * 2 + 1; // amount
  // 解析...
}
```

---

## 目录结构

```
practice-3-4-solutuions/
├── README.md        # 本文件
├── MyWallet.sol     # 实战3答案
├── esRNT.sol        # 实战4合约
├── readLocks.ts     # Viem读取脚本
├── package.json     # Node配置
└── tsconfig.json    # TS配置
```
