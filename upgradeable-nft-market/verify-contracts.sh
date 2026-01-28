#!/bin/bash

# ============================================
# Etherscan Contract Verification Script
# ============================================
# 
# 使用前请设置环境变量：
# export ETHERSCAN_API_KEY=your_api_key
#
# 运行方式：
# chmod +x verify-contracts.sh
# ./verify-contracts.sh
# ============================================

echo "============================================"
echo "   Verifying Contracts on Etherscan"
echo "============================================"

# 检查 ETHERSCAN_API_KEY
if [ -z "$ETHERSCAN_API_KEY" ]; then
    echo "Error: ETHERSCAN_API_KEY is not set"
    echo "Please run: export ETHERSCAN_API_KEY=your_api_key"
    exit 1
fi

echo ""
echo "1. Verifying MarketNFT Implementation..."
forge verify-contract \
    0x866FC3Df183517066fd9Dd206E8a581Fa3211DE8 \
    src/MarketNFT.sol:MarketNFT \
    --chain sepolia \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --watch

echo ""
echo "2. Verifying PaymentToken Implementation..."
forge verify-contract \
    0x499Aad6Df756122a220D4e09462487feB13DC7fc \
    src/PaymentToken.sol:PaymentToken \
    --chain sepolia \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --watch

echo ""
echo "3. Verifying NFTMarketV1 Implementation..."
forge verify-contract \
    0xada6cb9971112Ca5e463Ab1123d57575b3C07C45 \
    src/NFTMarketV1.sol:NFTMarketV1 \
    --chain sepolia \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --watch

echo ""
echo "4. Verifying NFTMarketV2 Implementation..."
forge verify-contract \
    0x712Bb982eaf7384Ab39AaAd3e0E6a157697E71c3 \
    src/NFTMarketV2.sol:NFTMarketV2 \
    --chain sepolia \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --watch

echo ""
echo "============================================"
echo "   Verification Complete!"
echo "============================================"
echo ""
echo "Check contracts on Etherscan:"
echo "- MarketNFT:     https://sepolia.etherscan.io/address/0x866FC3Df183517066fd9Dd206E8a581Fa3211DE8#code"
echo "- PaymentToken:  https://sepolia.etherscan.io/address/0x499Aad6Df756122a220D4e09462487feB13DC7fc#code"
echo "- NFTMarketV1:   https://sepolia.etherscan.io/address/0xada6cb9971112Ca5e463Ab1123d57575b3C07C45#code"
echo "- NFTMarketV2:   https://sepolia.etherscan.io/address/0x712Bb982eaf7384Ab39AaAd3e0E6a157697E71c3#code"
