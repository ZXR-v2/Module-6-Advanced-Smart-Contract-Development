模块六：合约开发进阶 - 深入理解 EVM 运行 、 GAS 优化、合约审计与安全、合约升级

实战 1： 应用最小代理实现 ERC20 铸币工厂， 理解最小代理如何节省 Gas，同时理解 "公平" 发射的概念。

链接: https://decert.me/quests/75782f22-edb8-4e82-9b68-0a4f46fcaadd

对应代码：https://github.com/ZXR-v2/Module-6-Advanced-Smart-Contract-Development/tree/main/erc20-minimal-proxy-factory

实战 2：用所学的知识点，尝试优化 之前编写的 NFTMarknet gas 表现

链接: https://decert.me/quests/6a5ce6d6-0502-48be-8fe4-e38a0b35df62

原始NFTMarket和优化 NFTMarket 的比较：https://github.com/ZXR-v2/Module-5-Chain-Wallet-Dev/blob/main/NFTMarket/contracts/gas_compare.md

优化后的NFTMarket_V2源码：https://github.com/ZXR-v2/Module-5-Chain-Wallet-Dev/blob/main/NFTMarket/contracts/src/NFTMarket_V2.sol

github代码库：https://github.com/ZXR-v2/Module-5-Chain-Wallet-Dev/tree/main/NFTMarket/contracts

实战 3：掌握 EVM 存储布局，确定给定代码 的 owner 的Slot 位置，使用内联汇编读取和修改Owner

链接: https://decert.me/challenge/163c68ab-8adf-4377-a1c2-b5d0132edc69

对应代码：https://github.com/ZXR-v2/Module-6-Advanced-Smart-Contract-Development/blob/main/practice-3-4-solutuions/MyWallet.sol

实战 4：利用存储布局的理解，读取私有变量的值

链接：https://decert.me/quests/b0782759-4995-4bcb-85c2-2af749f0fde9

对应代码：https://github.com/ZXR-v2/Module-6-Advanced-Smart-Contract-Development/tree/main/practice-3-4-solutuions

实战 5：利用 Merkel 树及 MultiCall 等技术实现用户体验和 Gas 的优化

链接： https://decert.me/quests/faa435a5-f462-4f92-a209-3a7e8fdc4d81

对应代码：https://github.com/ZXR-v2/Module-6-Advanced-Smart-Contract-Development/tree/main/AirdopMerkleNFTMarket

功能说明：
- 基于 Merkle 树验证白名单用户（享受 50% 折扣）
- EIP-2612 Permit 授权（无需提前 approve）
- Multicall (delegateCall) 批量调用：permitPrePay + claimNFT
- 完整测试覆盖（17 个测试通过）
- TypeScript 脚本：Merkle 树构建、multicall 调用封装、完整 demo

实战 6：理解账户抽象 AA ( ERC4337 与 EIP7702 )，利用最新的上线的 EIP 7702 发起打包交易

链接： https://decert.me/quests/2c550f3e-0c29-46f8-a9ea-6258bb01b3ff

实战 7： 将 NFTMarket 合约改成可升级模式，在实战过程中理解可升级合约的编写，理解代理合约及实现合约的作用，以及如何对合约进行升级，如何开源逻辑实现合约

链接： https://decert.me/quests/ddbdd3c4-a633-49d7-adf9-34a6292ce3a8

对应代码：https://github.com/ZXR-v2/Module-6-Advanced-Smart-Contract-Development/tree/main/upgradeable-nft-market

功能说明：
- 可升级的 ERC721 NFT 合约 (UUPS 代理模式)
- NFTMarketV1：基础市场功能（上架、下架、购买）
- NFTMarketV2：新增离线签名上架功能
  - 签名内容：tokenId, price, nonce, deadline
  - 用户仅需一次 setApprovalForAll，每次上架只需签名
  - 支持签名直接购买（无需先上架）
- 完整升级测试（15 个测试用例通过）
- 升级前后状态保持一致验证

合约地址（Sepolia 测试网）：
- NFTMarket Proxy: [`0xaf3c313844E4cc1140B860FD3Dc9922bF32B2CAE`](https://sepolia.etherscan.io/address/0xaf3c313844E4cc1140B860FD3Dc9922bF32B2CAE)
- NFTMarketV1 Implementation: [`0xada6cb9971112Ca5e463Ab1123d57575b3C07C45`](https://sepolia.etherscan.io/address/0xada6cb9971112Ca5e463Ab1123d57575b3C07C45)
- NFTMarketV2 Implementation: [`0x712Bb982eaf7384Ab39AaAd3e0E6a157697E71c3`](https://sepolia.etherscan.io/address/0x712Bb982eaf7384Ab39AaAd3e0E6a157697E71c3)

练习 8: 深入理解合约升级涉及的存储布局

链接： https://decert.me/quests/8ea21ac0-fc65-414a-8afd-9507c0fa2d90

对应代码：https://github.com/ZXR-v2/Module-6-Advanced-Smart-Contract-Development/tree/main/practice-8-tests

功能说明：
- 验证 Mapping 中结构体末尾添加字段是安全的
- 验证 Mapping 中结构体开头/中间添加字段会导致数据损坏
- 验证 Array 中结构体添加字段（即使末尾）会导致数据错乱
- 使用 vm.load 直接读取存储槽，直观展示存储布局变化
- 完整测试用例验证各种升级场景

实战 9： 这个一个安全挑战题，你需要充当黑客，设法取出预先部署的 Vault 合约内的所有资金

链接：https://decert.me/quests/b5368265-89b3-4058-8a57-a41bde625f5b

实战 10：利用第三方服务（如 ChainLink Automation 等）实现对合约关键状态监控与自动化调用，

链接：https://decert.me/quests/072fccb4-a976-4cf9-933c-c4ef14e0f6eb
