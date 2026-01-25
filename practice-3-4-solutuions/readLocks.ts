import { createPublicClient, http, keccak256, toHex, pad } from "viem";
import { anvil } from "viem/chains";

// ========== 配置 ==========
// 部署后替换为实际地址（Anvil 默认第一个合约地址）
const CONTRACT_ADDRESS = "0x5FbDB2315678afecb367f032d93F642f64180aa3";

// 创建 Anvil 客户端
const client = createPublicClient({
  chain: anvil,
  transport: http("http://127.0.0.1:8545"),
});

/**
 * 存储布局分析：
 * - _locks 是第一个状态变量，slot 0 存储数组长度
 * - 数组元素从 keccak256(abi.encode(0)) 开始
 * - 每个 LockInfo 结构体占用 2 个 slots：
 *   - Slot N:   user (20 bytes, 低位) + startTime (8 bytes) + 4 bytes padding
 *   - Slot N+1: amount (32 bytes)
 */

async function readLocks() {
  // 1. 读取数组长度 (slot 0)
  const lengthHex = await client.getStorageAt({
    address: CONTRACT_ADDRESS,
    slot: toHex(0, { size: 32 }),
  });
  // lengthHex 转换为 BigInt, 如果 lengthHex 为空（undefined），则通过 || "0x0" 后默认为 0
  const length = BigInt(lengthHex || "0x0");
  console.log(`_locks 数组长度: ${length}\n`);

  // 2. 计算数组数据起始位置: keccak256(slot)
  const baseSlot = BigInt(keccak256(pad(toHex(0), { size: 32 })));

  // 3. 遍历读取每个元素
  for (let i = 0; i < Number(length); i++) {
    // 每个 LockInfo 占 2 个 slots
    const slot0 = baseSlot + BigInt(i * 2);     // user + startTime
    const slot1 = baseSlot + BigInt(i * 2 + 1); // amount

    // 读取两个 slots
    const data0 = await client.getStorageAt({
      address: CONTRACT_ADDRESS,
      slot: toHex(slot0, { size: 32 }),
    });
    const data1 = await client.getStorageAt({
      address: CONTRACT_ADDRESS,
      slot: toHex(slot1, { size: 32 }),
    });

    // 解析 slot0: user (低 20 bytes) + startTime (接下来 8 bytes)
    // data0 = 0x + 64 hex chars = 32 bytes
    // 布局 (从右到左): [user 20B][startTime 8B][padding 4B]
    const data0Clean = (data0 || "0x").slice(2).padStart(64, "0");
    
    // user: 最后 40 hex chars (20 bytes)
    const userHex = "0x" + data0Clean.slice(-40);
    
    // startTime: 倒数 41-56 位 (8 bytes = 16 hex chars)
    const startTimeHex = "0x" + data0Clean.slice(-56, -40);
    const startTime = BigInt(startTimeHex);

    // amount: slot1 全部
    const amount = BigInt(data1 || "0x0");

    console.log(
      `locks[${i}]: user: ${userHex}, startTime: ${startTime}, amount: ${amount}`
    );
  }
}

readLocks().catch(console.error);
