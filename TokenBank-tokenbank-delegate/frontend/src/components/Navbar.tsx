'use client';

/**
 * ============================================================================
 * 导航栏组件
 * ============================================================================
 * 
 * 【修改说明 - 添加EIP-7702导航】
 * 
 * 原来只有TokenBank V2一个页面，现在添加了EIP-7702页面的导航链接。
 * 用户可以方便地在不同存款方式之间切换：
 * 
 * - TokenBank V2: 传统的两步存款（approve + deposit）和transferWithCallback一步存款
 * - EIP-7702: 使用MetaMask Delegator的批量执行功能，一个交易完成所有操作
 */

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { ConnectWallet } from './ConnectWallet';

export function Navbar() {
  const pathname = usePathname();
  
  return (
    <nav className="bg-white border-b border-gray-200 shadow-sm">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Logo和导航链接 */}
          <div className="flex items-center space-x-8">
            <Link href="/" className="text-green-600 text-xl font-bold">
              TokenBank
            </Link>
            
            {/* 导航链接 */}
            <div className="hidden md:flex items-center space-x-4">
              <Link 
                href="/"
                className={`px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                  pathname === '/' 
                    ? 'bg-green-100 text-green-700' 
                    : 'text-gray-600 hover:text-green-600 hover:bg-gray-100'
                }`}
              >
                V2 (Hook回调)
              </Link>
              <Link 
                href="/eip7702"
                className={`px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                  pathname === '/eip7702' 
                    ? 'bg-indigo-100 text-indigo-700' 
                    : 'text-gray-600 hover:text-indigo-600 hover:bg-gray-100'
                }`}
              >
                EIP-7702 (批量执行)
              </Link>
            </div>
          </div>
          
          {/* 钱包连接按钮 */}
          <div className="flex items-center">
            <ConnectWallet />
          </div>
        </div>
        
        {/* 移动端导航 */}
        <div className="md:hidden pb-3">
          <div className="flex space-x-2">
            <Link 
              href="/"
              className={`flex-1 text-center px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                pathname === '/' 
                  ? 'bg-green-100 text-green-700' 
                  : 'text-gray-600 hover:text-green-600 hover:bg-gray-100'
              }`}
            >
              V2
            </Link>
            <Link 
              href="/eip7702"
              className={`flex-1 text-center px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                pathname === '/eip7702' 
                  ? 'bg-indigo-100 text-indigo-700' 
                  : 'text-gray-600 hover:text-indigo-600 hover:bg-gray-100'
              }`}
            >
              EIP-7702
            </Link>
          </div>
        </div>
      </div>
    </nav>
  );
}
