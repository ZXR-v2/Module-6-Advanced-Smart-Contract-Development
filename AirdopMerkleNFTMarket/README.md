# AirdopMerkleNFTMarket

一个基于 Merkle 树验证白名单的 NFT 交易市场，支持 EIP-2612 Permit 授权和 Multicall 批量调用。

## 功能特点

### 核心功能

1. **Merkle 树白名单验证**
   - 使用 Merkle 树高效验证用户是否在白名单中
   - 白名单用户享受 50% 的价格优惠

2. **EIP-2612 Permit 授权**
   - Token 支持 permit 签名授权，无需提前 approve
   - 节省 Gas，提升用户体验

3. **Multicall 批量调用**
   - 使用 `delegateCall` 方式实现 multicall
   - 一次交易完成 `permitPrePay()` 和 `claimNFT()` 两个操作

### 合约架构

```
├── src/
│   ├── PermitToken.sol        # ERC20 代币，支持 EIP-2612 Permit
│   ├── MarketNFT.sol          # ERC721 NFT 合约
│   └── AirdopMerkleNFTMarket.sol  # 主市场合约
├── scripts/
│   ├── merkle-tree.ts         # Merkle 树构建脚本
│   ├── generate-proof.ts      # 生成 Merkle 证明
│   └── multicall-helper.ts    # Multicall 调用封装
└── test/
    └── AirdopMerkleNFTMarket.t.sol  # 测试用例
```

## 安装

### 1. 安装 Foundry 依赖

```bash
cd AirdopMerkleNFTMarket
forge install foundry-rs/forge-std --no-commit
forge install OpenZeppelin/openzeppelin-contracts --no-commit
```

### 2. 安装 Node.js 依赖 (用于 Merkle 树脚本)

```bash
npm install
```

## 编译

```bash
forge build
```

## 测试

```bash
# 运行所有测试
forge test -vvv

# 运行特定测试
forge test --match-test test_ClaimNFTWithDiscount -vvv

# 查看测试覆盖率
forge coverage
```

## Merkle 树使用

### 1. 构建 Merkle 树

编辑 `scripts/merkle-tree.ts` 中的 `whitelist` 数组，添加白名单地址：

```typescript
const whitelist = [
    "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
    "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
    // 添加更多地址...
];
```

运行构建脚本：

```bash
npm run build:tree
```

输出将保存到 `merkle-data/merkle-tree.json`。

### 2. 生成特定地址的证明

```bash
npx ts-node scripts/generate-proof.ts 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
```

## 部署

### 1. 配置环境变量

```bash
cp .env.example .env
# 编辑 .env 文件，填入私钥和 RPC URL
```

### 2. 部署到测试网

```bash
source .env
forge script script/Deploy.s.sol:DeployScript --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

## Multicall 使用示例

### TypeScript 调用示例

```typescript
import { ethers } from "ethers";

// 构建 multicall 数据
const iface = new ethers.Interface(MARKET_ABI);

// 1. permitPrePay 调用数据
const permitPrePayData = iface.encodeFunctionData("permitPrePay", [
    buyerAddress,
    marketAddress,
    discountedPrice,
    deadline,
    v, r, s
]);

// 2. claimNFT 调用数据
const claimNFTData = iface.encodeFunctionData("claimNFT", [
    tokenId,
    merkleProof
]);

// 执行 multicall
const market = new ethers.Contract(marketAddress, MARKET_ABI, signer);
const tx = await market.multicall([permitPrePayData, claimNFTData]);
await tx.wait();
```

### 完整示例

查看 `scripts/multicall-helper.ts` 获取完整的 multicall 调用封装。

## 合约方法

### AirdopMerkleNFTMarket

| 方法 | 描述 |
|------|------|
| `list(tokenId, price)` | 上架 NFT |
| `delist(tokenId)` | 下架 NFT |
| `buy(tokenId)` | 普通购买（无折扣） |
| `permitPrePay(...)` | Permit 授权（用于 multicall） |
| `claimNFT(tokenId, merkleProof)` | 白名单用户购买（50% 折扣） |
| `multicall(data[])` | 批量调用（delegateCall） |
| `verifyWhitelist(account, proof)` | 验证白名单 |
| `getDiscountedPrice(tokenId)` | 获取折扣价格 |

## 测试用例覆盖

- ✅ NFT 上架/下架
- ✅ 普通购买流程
- ✅ 白名单验证
- ✅ Permit 签名生成与验证
- ✅ Multicall 批量调用
- ✅ 折扣价格计算
- ✅ 防止重复购买
- ✅ 权限控制
- ✅ 错误处理

## 安全考虑

1. **重入攻击防护**: 使用 OpenZeppelin 的 `ReentrancyGuard`
2. **Merkle 证明验证**: 使用双重 keccak256 哈希防止第二预像攻击
3. **Permit 安全**: 使用标准 EIP-2612 实现
4. **访问控制**: 仅 owner 可修改 Merkle root

## License

MIT
