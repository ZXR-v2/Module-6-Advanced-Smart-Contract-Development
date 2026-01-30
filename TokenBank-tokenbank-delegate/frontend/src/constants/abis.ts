// MyToken (ERC20) ABI - 从Sepolia部署的合约生成
export const TOKEN_ABI = [
  {
    type: "constructor",
    inputs: [{ name: "initialSupply", type: "uint256" }],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "allowance",
    inputs: [
      { name: "owner", type: "address" },
      { name: "spender", type: "address" },
    ],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "approve",
    inputs: [
      { name: "spender", type: "address" },
      { name: "value", type: "uint256" },
    ],
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "balanceOf",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "decimals",
    inputs: [],
    outputs: [{ name: "", type: "uint8" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "mint",
    inputs: [
      { name: "to", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "name",
    inputs: [],
    outputs: [{ name: "", type: "string" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "symbol",
    inputs: [],
    outputs: [{ name: "", type: "string" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "totalSupply",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "transfer",
    inputs: [
      { name: "to", type: "address" },
      { name: "value", type: "uint256" },
    ],
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "transferFrom",
    inputs: [
      { name: "from", type: "address" },
      { name: "to", type: "address" },
      { name: "value", type: "uint256" },
    ],
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "permit",
    inputs: [
      { name: "owner", type: "address" },
      { name: "spender", type: "address" },
      { name: "value", type: "uint256" },
      { name: "deadline", type: "uint256" },
      { name: "v", type: "uint8" },
      { name: "r", type: "bytes32" },
      { name: "s", type: "bytes32" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "nonces",
    inputs: [{ name: "owner", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "DOMAIN_SEPARATOR",
    inputs: [],
    outputs: [{ name: "", type: "bytes32" }],
    stateMutability: "view",
  },
  {
    type: "event",
    name: "Transfer",
    inputs: [
      { indexed: true, name: "from", type: "address" },
      { indexed: true, name: "to", type: "address" },
      { indexed: false, name: "value", type: "uint256" },
    ],
  },
  {
    type: "event",
    name: "Approval",
    inputs: [
      { indexed: true, name: "owner", type: "address" },
      { indexed: true, name: "spender", type: "address" },
      { indexed: false, name: "value", type: "uint256" },
    ],
  },
] as const;

// TokenBank ABI - 从Sepolia部署的合约生成
export const TOKEN_BANK_ABI = [
  {
    type: "constructor",
    inputs: [{ name: "_token", type: "address" }],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "balanceOf",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "balances",
    inputs: [{ name: "", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "deposit",
    inputs: [{ name: "amount", type: "uint256" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "token",
    inputs: [],
    outputs: [{ name: "", type: "address" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "totalDeposits",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "withdraw",
    inputs: [{ name: "amount", type: "uint256" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "event",
    name: "Deposit",
    inputs: [
      { indexed: true, name: "user", type: "address" },
      { indexed: false, name: "amount", type: "uint256" },
    ],
  },
  {
    type: "event",
    name: "Withdraw",
    inputs: [
      { indexed: true, name: "user", type: "address" },
      { indexed: false, name: "amount", type: "uint256" },
    ],
  },
  {
    type: "error",
    name: "InsufficientBalance",
    inputs: [],
  },
  {
    type: "error",
    name: "ZeroAmount",
    inputs: [],
  },
] as const;

// MyTokenV2 ABI - 继承MyToken，添加transferWithCallback
export const TOKEN_V2_ABI = [
  ...TOKEN_ABI,
  {
    type: "function",
    name: "transferWithCallback",
    inputs: [
      { name: "to", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "nonpayable",
  },
] as const;

// TokenBankV2 ABI - 继承TokenBank，添加tokensReceived
export const TOKEN_BANK_V2_ABI = [
  ...TOKEN_BANK_ABI,
  {
    type: "function",
    name: "tokensReceived",
    inputs: [
      { name: "from", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [{ name: "", type: "bytes4" }],
    stateMutability: "nonpayable",
  },
  {
    type: "event",
    name: "DepositWithCallback",
    inputs: [
      { indexed: true, name: "user", type: "address" },
      { indexed: false, name: "amount", type: "uint256" },
    ],
  },
] as const;

// MyTokenPermit (ERC20 with EIP-2612 Permit) ABI
export const TOKEN_PERMIT_ABI = [
  ...TOKEN_ABI,
  {
    type: "function",
    name: "permit",
    inputs: [
      { name: "owner", type: "address" },
      { name: "spender", type: "address" },
      { name: "value", type: "uint256" },
      { name: "deadline", type: "uint256" },
      { name: "v", type: "uint8" },
      { name: "r", type: "bytes32" },
      { name: "s", type: "bytes32" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "nonces",
    inputs: [{ name: "owner", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "DOMAIN_SEPARATOR",
    inputs: [],
    outputs: [{ name: "", type: "bytes32" }],
    stateMutability: "view",
  },
] as const;

// TokenBankPermit ABI
export const TOKEN_BANK_PERMIT_ABI = [
  ...TOKEN_BANK_ABI,
  {
    type: "function",
    name: "permitDeposit",
    inputs: [
      { name: "amount", type: "uint256" },
      { name: "deadline", type: "uint256" },
      { name: "v", type: "uint8" },
      { name: "r", type: "bytes32" },
      { name: "s", type: "bytes32" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "event",
    name: "PermitDeposit",
    inputs: [
      { indexed: true, name: "user", type: "address" },
      { indexed: false, name: "amount", type: "uint256" },
    ],
  },
  {
    type: "error",
    name: "PermitFailed",
    inputs: [],
  },
] as const;

// Permit2 ABI
export const PERMIT2_ABI = [
  {
    type: "function",
    name: "permitTransferFrom",
    inputs: [
      {
        name: "permit",
        type: "tuple",
        components: [
          {
            name: "permitted",
            type: "tuple",
            components: [
              { name: "token", type: "address" },
              { name: "amount", type: "uint256" },
            ],
          },
          { name: "nonce", type: "uint256" },
          { name: "deadline", type: "uint256" },
        ],
      },
      {
        name: "transferDetails",
        type: "tuple",
        components: [
          { name: "to", type: "address" },
          { name: "requestedAmount", type: "uint256" },
        ],
      },
      { name: "owner", type: "address" },
      { name: "signature", type: "bytes" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "nonceBitmap",
    inputs: [
      { name: "owner", type: "address" },
      { name: "wordPos", type: "uint256" },
    ],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "DOMAIN_SEPARATOR",
    inputs: [],
    outputs: [{ name: "", type: "bytes32" }],
    stateMutability: "view",
  },
] as const;

// TokenBankPermit2 ABI
export const TOKEN_BANK_PERMIT2_ABI = [
  ...TOKEN_BANK_ABI,
  {
    type: "function",
    name: "depositWithPermit2",
    inputs: [
      {
        name: "permitTransfer",
        type: "tuple",
        components: [
          {
            name: "permitted",
            type: "tuple",
            components: [
              { name: "token", type: "address" },
              { name: "amount", type: "uint256" },
            ],
          },
          { name: "nonce", type: "uint256" },
          { name: "deadline", type: "uint256" },
        ],
      },
      { name: "owner", type: "address" },
      { name: "signature", type: "bytes" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "event",
    name: "Permit2Deposit",
    inputs: [
      { indexed: true, name: "user", type: "address" },
      { indexed: false, name: "amount", type: "uint256" },
    ],
  },
] as const;

/**
 * ============================================================================
 * EIP-7702 MetaMask Delegator ABI
 * ============================================================================
 * 
 * 【修改说明 - EIP-7702 新增】
 * 
 * 原理：
 * MetaMask的EIP7702StatelessDeleGator合约实现了EIP-7821（Minimal Batch Executor）接口。
 * 核心函数是execute，它接受一个mode参数和执行数据：
 * 
 * execute(bytes32 mode, bytes calldata executionData)
 * 
 * Mode参数说明（EIP-7821规范）：
 * - 0x00: 单次调用模式
 * - 0x01: 批量调用模式（我们使用这个）
 * 
 * 对于批量调用，executionData的编码格式为：
 * abi.encode(Execution[] calls)
 * 
 * 其中 Execution 结构体为：
 * struct Execution {
 *     address target;   // 目标合约地址
 *     uint256 value;    // 发送的ETH数量（通常为0）
 *     bytes data;       // 调用数据（如approve或deposit的calldata）
 * }
 * 
 * 工作流程：
 * 1. 构建approve调用的Execution对象
 * 2. 构建deposit调用的Execution对象
 * 3. 将两个Execution放入数组
 * 4. 编码并调用execute函数
 * 5. 两个操作在一个交易中原子执行
 */
export const EIP7702_DELEGATOR_ABI = [
  {
    // execute函数 - EIP-7821接口
    // 用于执行单次或批量调用
    type: "function",
    name: "execute",
    inputs: [
      { 
        name: "mode", 
        type: "bytes32",
        // mode[0] = 0x00 表示单次调用
        // mode[0] = 0x01 表示批量调用
      },
      { 
        name: "executionData", 
        type: "bytes",
        // 对于批量调用，这是abi.encode(Execution[])
      },
    ],
    outputs: [],
    stateMutability: "payable",
  },
  {
    // executeBatch函数 - 便捷的批量执行接口
    // 直接接受Execution数组，内部调用execute
    type: "function",
    name: "executeBatch",
    inputs: [
      {
        name: "executions",
        type: "tuple[]",
        components: [
          { name: "target", type: "address" },  // 目标合约地址
          { name: "value", type: "uint256" },   // ETH数量
          { name: "data", type: "bytes" },      // 调用数据
        ],
      },
    ],
    outputs: [],
    stateMutability: "payable",
  },
  {
    // isValidSignature函数 - EIP-1271接口
    // 用于验证签名（由EOA所有者签名）
    type: "function",
    name: "isValidSignature",
    inputs: [
      { name: "hash", type: "bytes32" },
      { name: "signature", type: "bytes" },
    ],
    outputs: [{ name: "", type: "bytes4" }],
    stateMutability: "view",
  },
] as const;

