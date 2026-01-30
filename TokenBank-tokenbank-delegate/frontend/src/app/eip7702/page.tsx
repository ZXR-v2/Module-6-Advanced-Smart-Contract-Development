'use client';

/**
 * ============================================================================
 * EIP-7702 TokenBank 存款页面
 * ============================================================================
 * 
 * 【修改说明 - 新增EIP-7702功能】
 * 
 * ===== 修改前（传统方式）=====
 * 用户需要执行两个独立的交易：
 * 1. 第一个交易：调用Token合约的approve函数，授权TokenBank合约
 * 2. 等待交易确认
 * 3. 第二个交易：调用TokenBank合约的deposit函数
 * 
 * 问题：
 * - 需要两次签名和两次gas费用
 * - 用户体验差，需要等待第一个交易确认
 * - 存在approve后但deposit前的风险窗口
 * 
 * ===== 修改后（EIP-7702 + EIP-5792方式）=====
 * 
 * 【重要】正确的实现方式：
 * MetaMask 不直接暴露 eth_signAuthorization RPC 方法给 DApp 调用。
 * 正确的方式是使用 EIP-5792 的 wallet_sendCalls API（在 Wagmi 中是 useSendCalls hook）。
 * 
 * 工作流程：
 * 1. DApp 调用 useSendCalls 发送批量交易请求（包含 approve + deposit）
 * 2. MetaMask 检测到批量调用请求
 * 3. 如果用户的 EOA 尚未升级为智能账户，MetaMask 会自动弹窗提示用户"升级到智能账户"
 * 4. 用户确认后，MetaMask 在后台处理 EIP-7702 授权
 * 5. 所有操作在一个交易中原子执行
 * 
 * 原理详解：
 * 
 * 1. EIP-5792 (Wallet Call API)：
 *    - 标准化的钱包批量调用接口
 *    - 通过 useSendCalls hook 发送批量交易
 *    - 钱包（如MetaMask）负责处理底层的 EIP-7702 授权
 * 
 * 2. 自动升级流程：
 *    - 用户首次使用批量交易时
 *    - MetaMask 会弹窗提示"升级到智能账户"
 *    - 用户确认后，EOA 自动获得批量执行能力
 *    - 这个过程对 DApp 完全透明
 * 
 * 3. 批量操作：
 *    - 第一个操作：调用Token.approve(TokenBank, amount)
 *    - 第二个操作：调用TokenBank.deposit(amount)
 *    - 两个操作顺序执行，第二个操作可以依赖第一个操作的结果
 * 
 * 4. 安全性：
 *    - 所有操作原子执行，要么全部成功，要么全部回滚
 *    - 用户的私钥仍然完全控制账户
 *    - MetaMask 的 Delegator 合约是无状态的
 * 
 * 优势：
 * - 一次签名，一次gas费用
 * - 更好的用户体验（钱包自动处理升级）
 * - 消除approve后的风险窗口
 * - 保持向后兼容性（EOA仍然是EOA）
 */

import { useState, useEffect, useCallback } from 'react';
import { useAccount, useReadContract, useSendCalls, usePublicClient } from 'wagmi';
import { parseEther, formatEther } from 'viem';
import { getCallsStatus } from '@wagmi/core';
import { TOKEN_V2_ABI, TOKEN_BANK_V2_ABI } from '@/constants/abis';
import { CONTRACTS, EIP7702_CONTRACTS, EXPLORER_URL } from '@/constants/addresses';
import { config as wagmiConfig } from '@/config/wagmi';

type AddressType = `0x${string}`;

export default function EIP7702Deposit() {
  const { address, isConnected } = useAccount();
  const publicClient = usePublicClient();
  
  const [depositAmount, setDepositAmount] = useState('');
  const [isAuthorized, setIsAuthorized] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [transactionHash, setTransactionHash] = useState<string | null>(null);
  const [statusError, setStatusError] = useState<string | null>(null);
  const [statusLoading, setStatusLoading] = useState(false);

  /**
   * ===== EIP-5792: useSendCalls Hook =====
   * 这是实现 EIP-7702 批量交易的推荐方式（MetaMask 官方推荐）
   * 
   * 为什么用 useSendCalls 而不是直接调用 eth_signAuthorization：
   * 1. MetaMask 不直接暴露 eth_signAuthorization RPC 方法
   * 2. useSendCalls 是 EIP-5792 标准的实现
   * 3. MetaMask 会自动处理 EIP-7702 升级流程
   * 4. 用户首次使用时，MetaMask 会弹窗提示"升级到智能账户"
   * 5. 升级后，后续批量交易自动生效
   * 
   * 工作原理：
   * - 调用 sendCalls({ calls: [...] }) 发送批量交易
   * - MetaMask 检测到批量调用请求
   * - 如果 EOA 尚未升级，自动提示用户升级
   * - 用户确认后，批量交易原子执行
   */
  const { 
    sendCalls, 
    data: sendCallsData, 
    error: sendCallsError, 
    isPending: isSendingCalls, 
    isSuccess: isSendCallsSuccess,
    reset: resetSendCalls
  } = useSendCalls();

  // 读取token余额
  const { data: tokenBalance, refetch: refetchTokenBalance } = useReadContract({
    address: CONTRACTS.MyTokenV2 as AddressType,
    abi: TOKEN_V2_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  });

  // 读取bank余额
  const { data: bankBalance, refetch: refetchBankBalance } = useReadContract({
    address: CONTRACTS.TokenBankV2 as AddressType,
    abi: TOKEN_BANK_V2_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  });

  // 读取当前allowance
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: CONTRACTS.MyTokenV2 as AddressType,
    abi: TOKEN_V2_ABI,
    functionName: 'allowance',
    args: address ? [address, CONTRACTS.TokenBankV2 as AddressType] : undefined,
  });

  // 读取token符号
  const { data: tokenSymbol } = useReadContract({
    address: CONTRACTS.MyTokenV2 as AddressType,
    abi: TOKEN_V2_ABI,
    functionName: 'symbol',
    args: [],
  });

  // 检查EOA是否已经被授权（通过检查账户的code）
  const checkAuthorization = useCallback(async () => {
    if (!address || !publicClient) return;
    
    try {
      const code = await publicClient.getCode({ address: address as AddressType });
      // 如果code不为空且以0xef0100开头，说明已经有EIP-7702授权
      // 0xef0100是EIP-7702的delegation designator
      if (code && code.startsWith('0xef0100')) {
        setIsAuthorized(true);
      } else {
        setIsAuthorized(false);
      }
    } catch (err) {
      console.error('检查授权状态失败:', err);
    }
  }, [address, publicClient]);

  useEffect(() => {
    checkAuthorization();
  }, [checkAuthorization]);

  // 当 sendCalls 成功后刷新授权状态
  useEffect(() => {
    if (isSendCallsSuccess && sendCallsData?.id) {
      checkAuthorization();
    }
  }, [isSendCallsSuccess, sendCallsData, checkAuthorization]);

  // 处理 sendCalls 错误
  useEffect(() => {
    if (sendCallsError) {
      setError(sendCallsError.message);
    }
  }, [sendCallsError]);

  /**
   * ===== 处理批量存款 =====
   * 
   * 这是 EIP-7702 + EIP-5792 的核心实现：
   * 
   * 1. 构建 calls 数组，包含 approve 和 deposit 两个调用
   * 2. 调用 sendCalls() 发送批量交易请求
   * 3. MetaMask 会自动：
   *    - 检测是否需要升级 EOA 到智能账户
   *    - 如果需要，弹窗提示用户确认升级
   *    - 升级后执行批量交易
   * 
   * 为什么这样更好：
   * - 不需要手动处理 eth_signAuthorization
   * - 钱包自动处理 EIP-7702 升级流程
   * - 更好的用户体验
   */
  const handleBatchDeposit = () => {
    if (!address || !depositAmount) return;
    
    setError(null);
    setStatusError(null);
    setTransactionHash(null);
    resetSendCalls();
    
    const amount = parseEther(depositAmount);
    
    /**
     * ===== 构建批量调用 =====
     * 
     * calls 数组中的每个对象代表一个合约调用：
     * - to: 目标合约地址
     * - abi: 合约 ABI
     * - functionName: 要调用的函数名
     * - args: 函数参数
     * - value: 发送的 ETH 数量（可选）
     * 
     * 执行顺序：按数组顺序依次执行
     * 原子性：所有调用要么全部成功，要么全部回滚
     */
    sendCalls({
      calls: [
        // 第一个调用：approve - 授权 TokenBank 使用代币
        {
          to: CONTRACTS.MyTokenV2 as AddressType,
          abi: TOKEN_V2_ABI,
          functionName: 'approve',
          args: [CONTRACTS.TokenBankV2 as AddressType, amount],
        },
        // 第二个调用：deposit - 存入代币到 TokenBank
        {
          to: CONTRACTS.TokenBankV2 as AddressType,
          abi: TOKEN_BANK_V2_ABI,
          functionName: 'deposit',
          args: [amount],
        },
      ],
    });
  };

  /**
   * ===== 检查交易状态 =====
   * 
   * 使用 getCallsStatus 查询批量交易的状态
   * 当状态变为 'success' 时，可以获取交易哈希
   */
  const handleCheckStatus = async () => {
    if (!sendCallsData?.id) return;
    
    setStatusLoading(true);
    setStatusError(null);
    
    try {
      const status = await getCallsStatus(wagmiConfig, { id: sendCallsData.id });
      console.log('Transaction status:', status);
      
      if (status.status === 'success' && status.receipts?.[0]?.transactionHash) {
        setTransactionHash(status.receipts[0].transactionHash);
        refetchTokenBalance();
        refetchBankBalance();
        refetchAllowance();
        checkAuthorization();
        setDepositAmount('');
      } else if (status.status === 'failure') {
        setStatusError('交易失败');
      }
    } catch (err) {
      console.error('检查状态失败:', err);
      setStatusError(err instanceof Error ? err.message : '检查状态失败');
    } finally {
      setStatusLoading(false);
    }
  };

  if (!isConnected) {
    return (
      <div className="text-center py-12">
        <h1 className="text-3xl font-bold mb-4 text-gray-900">TokenBank - EIP-7702</h1>
        <p className="text-gray-600">请连接钱包以继续</p>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* 页面标题 */}
      <div className="text-center">
        <h1 className="text-3xl font-bold mb-2 text-gray-900">TokenBank - EIP-7702</h1>
        <p className="text-gray-600">使用 EIP-5792 批量交易在一个操作中完成授权和存款</p>
      </div>

      {/* 余额显示 */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="p-6 bg-white rounded-lg border border-gray-200 shadow-sm">
          <h3 className="text-sm text-gray-500 mb-1">钱包代币余额</h3>
          <p className="text-2xl font-semibold text-gray-900">
            {tokenBalance ? formatEther(tokenBalance as bigint) : '0'} {tokenSymbol || 'MTK'}
          </p>
        </div>
        <div className="p-6 bg-white rounded-lg border border-gray-200 shadow-sm">
          <h3 className="text-sm text-gray-500 mb-1">银行存款余额</h3>
          <p className="text-2xl font-semibold text-gray-900">
            {bankBalance ? formatEther(bankBalance as bigint) : '0'} {tokenSymbol || 'MTK'}
          </p>
        </div>
      </div>

      {/* 授权状态 */}
      <div className={`p-4 rounded-lg border ${isAuthorized ? 'bg-green-50 border-green-200' : 'bg-yellow-50 border-yellow-200'}`}>
        <div className="flex items-center justify-between">
          <div>
            <h3 className="font-semibold text-gray-900">EIP-7702 智能账户状态</h3>
            <p className="text-sm text-gray-600">
              {isAuthorized 
                ? '✓ 已升级 - 您的EOA已经是智能账户，可以使用批量执行功能' 
                : '⚠ 未升级 - 首次使用批量交易时，MetaMask 会提示您升级到智能账户'}
            </p>
          </div>
        </div>
        <div className="mt-2 text-xs text-gray-500">
          MetaMask Delegator 合约: {EIP7702_CONTRACTS.MetaMaskDelegator}
        </div>
      </div>

      {/* 错误提示 */}
      {error && (
        <div className="p-4 bg-red-50 rounded-lg border border-red-200">
          <p className="text-red-700">{error}</p>
        </div>
      )}

      {/* 交易状态 */}
      {(sendCallsData || transactionHash) && (
        <div className="p-4 bg-blue-50 rounded-lg border border-blue-200">
          <h3 className="text-sm font-semibold text-blue-900 mb-2">交易记录</h3>
          <div className="space-y-2">
            {sendCallsData && (
              <div className="text-sm text-gray-700">
                <p>批量交易 ID: <code className="bg-gray-100 px-1 rounded">{sendCallsData.id}</code></p>
              </div>
            )}
            {transactionHash && (
              <div className="flex items-center justify-between text-sm">
                <span className="text-green-700 font-medium">交易已确认!</span>
                <a
                  href={`${EXPLORER_URL}${transactionHash}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-blue-600 hover:text-blue-800 underline"
                >
                  在Etherscan查看
                </a>
              </div>
            )}
            {sendCallsData && !transactionHash && (
              <button
                onClick={handleCheckStatus}
                disabled={statusLoading}
                className={`w-full rounded-lg border border-solid px-6 py-3 font-medium transition-colors ${
                  statusLoading
                    ? 'bg-gray-100 text-gray-400 border-gray-300 cursor-not-allowed'
                    : 'bg-purple-50 hover:bg-purple-100 text-purple-700 border-purple-300 cursor-pointer'
                }`}
              >
                {statusLoading ? '检查中...' : '检查交易状态'}
              </button>
            )}
            {statusError && (
              <div className="bg-red-50 border border-red-200 rounded-lg p-2 mt-2">
                <div className="text-sm text-red-600">{statusError}</div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* 一键存款（推荐） */}
      <div className="p-6 bg-gradient-to-r from-indigo-50 to-purple-50 rounded-lg border-2 border-indigo-300 shadow-sm">
        <div className="flex items-start justify-between mb-4">
          <div>
            <h2 className="text-xl font-semibold text-gray-900">批量存款（EIP-5792 + EIP-7702）</h2>
            <p className="text-sm text-gray-600 mt-1">在一个交易中完成 approve + deposit（首次使用会提示升级智能账户）</p>
          </div>
          <span className="px-3 py-1 bg-indigo-500 text-white text-xs font-semibold rounded-full">推荐</span>
        </div>
        <div className="space-y-4">
          <div>
            <label className="block text-sm text-gray-600 mb-1">存款数量</label>
            <input
              type="number"
              value={depositAmount}
              onChange={(e) => setDepositAmount(e.target.value)}
              placeholder="输入存款数量"
              className="w-full px-4 py-2 bg-white border border-indigo-300 rounded-lg focus:outline-none focus:border-indigo-500 text-gray-900"
            />
          </div>
          <div className="text-sm text-gray-600">
            当前授权额度: {allowance ? formatEther(allowance as bigint) : '0'} {tokenSymbol || 'MTK'}
          </div>
          <button
            onClick={handleBatchDeposit}
            disabled={isSendingCalls || !depositAmount}
            className="w-full px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white disabled:bg-gray-300 disabled:cursor-not-allowed rounded-lg transition-colors font-medium"
          >
            {isSendingCalls ? '处理中...' : '发送批量交易'}
          </button>
        </div>
      </div>

      {/* 原理说明 */}
      <div className="p-6 bg-gray-50 rounded-lg border border-gray-200">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">EIP-7702 + EIP-5792 工作原理</h2>
        
        <div className="space-y-4 text-sm text-gray-700">
          <div className="p-4 bg-white rounded border border-gray-200">
            <h3 className="font-semibold text-gray-900 mb-2">1. 传统方式（两个交易）</h3>
            <div className="pl-4 border-l-2 border-red-300">
              <p>交易1: Token.approve(TokenBank, amount) → 等待确认</p>
              <p>交易2: TokenBank.deposit(amount) → 等待确认</p>
              <p className="mt-2 text-red-600">问题: 两次签名、两次gas费用、中间有风险窗口</p>
            </div>
          </div>
          
          <div className="p-4 bg-white rounded border border-gray-200">
            <h3 className="font-semibold text-gray-900 mb-2">2. EIP-5792 方式（使用 useSendCalls）</h3>
            <div className="pl-4 border-l-2 border-green-300">
              <p>步骤1: DApp 调用 useSendCalls 发送批量交易请求</p>
              <p>步骤2: MetaMask 检测到批量调用，自动提示升级智能账户（如需要）</p>
              <p>步骤3: 用户确认后，批量交易原子执行</p>
              <p className="mt-2 text-green-600">优势: 一次签名、一次gas费用、原子执行、钱包自动处理升级</p>
            </div>
          </div>
          
          <div className="p-4 bg-white rounded border border-gray-200">
            <h3 className="font-semibold text-gray-900 mb-2">3. 为什么使用 useSendCalls 而不是 eth_signAuthorization</h3>
            <div className="pl-4 border-l-2 border-blue-300">
              <p>• MetaMask 不直接暴露 eth_signAuthorization RPC 方法给 DApp</p>
              <p>• EIP-5792 (wallet_sendCalls) 是标准化的钱包批量调用接口</p>
              <p>• 钱包负责处理底层的 EIP-7702 授权，对 DApp 透明</p>
              <p>• 更好的用户体验和更简单的代码实现</p>
            </div>
          </div>
          
          <div className="p-4 bg-white rounded border border-gray-200">
            <h3 className="font-semibold text-gray-900 mb-2">4. 代码变更对比</h3>
            <div className="pl-4 border-l-2 border-purple-300">
              <p className="font-mono text-xs bg-gray-100 p-2 rounded mb-2">
                {`// 修改前：需要两次调用`}<br/>
                {`await token.approve(bank, amount);`}<br/>
                {`await bank.deposit(amount);`}
              </p>
              <p className="font-mono text-xs bg-gray-100 p-2 rounded">
                {`// 修改后：使用 useSendCalls 一次批量调用`}<br/>
                {`sendCalls({`}<br/>
                {`  calls: [`}<br/>
                {`    { to: token, abi, functionName: 'approve', args: [...] },`}<br/>
                {`    { to: bank, abi, functionName: 'deposit', args: [...] }`}<br/>
                {`  ]`}<br/>
                {`});`}
              </p>
            </div>
          </div>

          <div className="p-4 bg-white rounded border border-gray-200">
            <h3 className="font-semibold text-gray-900 mb-2">5. MetaMask Delegator 合约</h3>
            <div className="pl-4 border-l-2 border-orange-300">
              <p>地址: {EIP7702_CONTRACTS.MetaMaskDelegator}</p>
              <p>类型: EIP7702StatelessDeleGator（无状态设计）</p>
              <p>功能: MetaMask 在后台使用此合约实现批量执行</p>
              <p>安全: 不存储任何用户数据，EOA仍完全由用户控制</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
