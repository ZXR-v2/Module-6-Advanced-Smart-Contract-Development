# Upgradeable NFT Market

可升级的 NFT 市场合约，基于 UUPS 代理模式实现。

## 功能特性

### V1 版本功能
- ✅ NFT 上架 (`list`)
- ✅ NFT 下架 (`delist`)
- ✅ 购买 NFT (`buy`)
- ✅ 手续费管理
- ✅ 重入攻击保护

### V2 版本新增功能
- ✅ **离线签名上架** (`listWithSignature`) - 卖家签名后，任何人都可以提交上架
- ✅ **签名直接购买** (`buyWithSignature`) - 买家直接使用卖家签名购买，无需先上架
- ✅ 签名重放保护
- ✅ 签名过期检查
- ✅ 批量取消签名

## 合约地址 (Sepolia Testnet)

### 代理合约（用户交互地址）
| 合约 | 地址 |
|------|------|
| NFTMarket Proxy | [`0xaf3c313844E4cc1140B860FD3Dc9922bF32B2CAE`](https://sepolia.etherscan.io/address/0xaf3c313844E4cc1140B860FD3Dc9922bF32B2CAE) |
| MarketNFT Proxy | [`0xD0b1e195C088659e98421628174f8eFB5E102a89`](https://sepolia.etherscan.io/address/0xD0b1e195C088659e98421628174f8eFB5E102a89) |
| PaymentToken Proxy | [`0x7f8d283B05375F90452C25325424cddEeab3daa4`](https://sepolia.etherscan.io/address/0x7f8d283B05375F90452C25325424cddEeab3daa4) |

### 实现合约
| 合约 | 地址 |
|------|------|
| NFTMarketV1 Implementation | [`0xada6cb9971112Ca5e463Ab1123d57575b3C07C45`](https://sepolia.etherscan.io/address/0xada6cb9971112Ca5e463Ab1123d57575b3C07C45) |
| NFTMarketV2 Implementation | [`0x712Bb982eaf7384Ab39AaAd3e0E6a157697E71c3`](https://sepolia.etherscan.io/address/0x712Bb982eaf7384Ab39AaAd3e0E6a157697E71c3) |
| MarketNFT Implementation | [`0x866FC3Df183517066fd9Dd206E8a581Fa3211DE8`](https://sepolia.etherscan.io/address/0x866FC3Df183517066fd9Dd206E8a581Fa3211DE8) |
| PaymentToken Implementation | [`0x499Aad6Df756122a220D4e09462487feB13DC7fc`](https://sepolia.etherscan.io/address/0x499Aad6Df756122a220D4e09462487feB13DC7fc) |

## 项目结构

```
upgradeable-nft-market/
├── src/
│   ├── MarketNFT.sol          # 可升级的 ERC721 NFT 合约
│   ├── PaymentToken.sol       # 可升级的 ERC20 支付代币（支持 Permit）
│   ├── NFTMarketV1.sol        # NFT 市场 V1 版本
│   └── NFTMarketV2.sol        # NFT 市场 V2 版本（新增签名上架）
├── test/
│   └── NFTMarket.t.sol        # 完整测试用例（包含升级测试）
├── script/
│   └── Deploy.s.sol           # 部署脚本
└── foundry.toml               # Foundry 配置
```

## 签名上架功能说明

V2 版本的核心创新是**离线签名上架**功能：

### 工作流程

1. **卖家设置授权**（仅需一次）
   ```solidity
   nft.setApprovalForAll(marketAddress, true);
   ```

2. **卖家生成签名**（链下）
   ```
   签名内容: (tokenId, price, nonce, deadline)
   使用 EIP-712 类型化数据签名
   ```

3. **买家/任意用户提交上架**
   ```solidity
   market.listWithSignature(tokenId, price, deadline, v, r, s);
   ```

4. **或者直接购买**
   ```solidity
   market.buyWithSignature(tokenId, price, deadline, v, r, s);
   ```

### EIP-712 签名结构

```solidity
bytes32 constant LISTING_TYPEHASH = keccak256(
    "Listing(uint256 tokenId,uint256 price,uint256 nonce,uint256 deadline)"
);
```

## 测试结果

所有 15 个测试用例通过：

```
✅ test_V1_Version - V1版本号验证
✅ test_V1_List - V1上架功能
✅ test_V1_Delist - V1下架功能
✅ test_V1_Buy - V1购买功能
✅ test_V1_WithdrawFees - V1手续费提取
✅ test_UpgradeToV2 - 升级到V2
✅ test_UpgradePreservesMultipleListings - 升级保持多个列表状态
✅ test_V1FunctionalityWorksAfterUpgrade - 升级后V1功能正常
✅ test_V2_ListWithSignature - V2签名上架
✅ test_V2_BuyWithSignature - V2签名购买
✅ test_V2_SignatureReplayProtection - 签名重放保护
✅ test_V2_ExpiredSignature - 过期签名拒绝
✅ test_V2_InvalidSignature - 无效签名拒绝
✅ test_V2_CancelAllSignatures - 取消所有签名
✅ test_CompleteUpgradeFlow - 完整升级流程测试
```

### 升级测试验证项

- ✅ 版本号从 `1.0.0` 升级到 `2.0.0`
- ✅ 累积手续费保持不变
- ✅ 已上架的 NFT 信息保持不变
- ✅ 升级后 V1 功能继续正常工作
- ✅ 升级后 V2 新功能可用

## 使用方法

### 安装依赖

```bash
forge install
```

### 编译

```bash
forge build
```

### 运行测试

```bash
forge test -vv
```

### 部署到 Sepolia

```bash
# 设置环境变量
export PRIVATE_KEY=your_private_key
export SEPOLIA_RPC_URL=your_rpc_url
export ETHERSCAN_API_KEY=your_etherscan_api_key

# 部署
forge script script/Deploy.s.sol:DeployScript --rpc-url $SEPOLIA_RPC_URL --broadcast --verify

# 升级到 V2
export MARKET_PROXY=deployed_proxy_address
export MARKET_V2_IMPL=deployed_v2_impl_address
forge script script/Deploy.s.sol:UpgradeToV2Script --rpc-url $SEPOLIA_RPC_URL --broadcast
```

## 测试输出日志

完整测试输出保存在 `test-output.log` 文件中。

关键升级测试日志：

```
========================================
     COMPLETE UPGRADE FLOW TEST
========================================

--- Phase 1: V1 Functionality ---
Market Version: 1.0.0
Listed NFT #1 for 100 tokens
Buyer purchased NFT #1

--- Phase 2: More Listings Before Upgrade ---
Listed NFT #2 for 200 tokens
Accumulated fees before upgrade: 2 tokens

--- Phase 3: Upgrade to V2 ---
Market Version after upgrade: 2.0.0
Accumulated fees after upgrade: 2 tokens
Fees preserved: true
Listing #2 preserved - seller: 0x2B5AD5c4795c026514f8317c7a215E218DcCD6cF
Listing #2 price: 200 active: true

--- Phase 4: V2 Signature Functionality ---
Created signature for NFT #4
Purchased NFT #4 with signature
NFT #4 new owner: 0x6813Eb9362372EEF6200f3b1dbC3f819671cBA69

--- Phase 5: V1 Functionality Still Works ---
Purchased NFT #2 using V1 buy function

========================================
     UPGRADE TEST COMPLETED SUCCESSFULLY
========================================
```

## 安全考虑

1. **UUPS 代理模式** - 只有 owner 可以升级合约
2. **重入保护** - 所有涉及资金转移的函数都有重入保护
3. **签名安全**
   - 使用 EIP-712 类型化签名
   - Nonce 机制防止重放攻击
   - 签名过期时间检查
   - 已使用签名不可重复使用

## License

MIT
