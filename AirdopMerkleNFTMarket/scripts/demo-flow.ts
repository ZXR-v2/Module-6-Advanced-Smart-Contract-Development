/**
 * Demo Flow Script
 * 
 * This script demonstrates the complete flow:
 * 1. Mint NFT to seller
 * 2. List NFT on market
 * 3. Transfer tokens to buyer
 * 4. Execute multicall (permit + claim) to purchase NFT with 50% discount
 */

import {
    createPublicClient,
    createWalletClient,
    http,
    parseAbi,
    formatEther,
    getAddress,
    type Address,
    type Hex,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { foundry } from "viem/chains";
import * as fs from "fs";
import * as path from "path";
import { buildMulticallData, executeMulticall } from "./multicall-helper";

// Contract ABIs
const TOKEN_ABI = parseAbi([
    "function transfer(address to, uint256 amount) returns (bool)",
    "function balanceOf(address account) view returns (uint256)",
    "function approve(address spender, uint256 amount) returns (bool)",
]);

const NFT_ABI = parseAbi([
    "function mint(address to) returns (uint256)",
    "function ownerOf(uint256 tokenId) view returns (address)",
    "function setApprovalForAll(address operator, bool approved)",
]);

const MARKET_ABI = parseAbi([
    "function list(uint256 tokenId, uint256 price)",
    "function getListing(uint256 tokenId) view returns (address seller, uint256 price, bool isActive)",
]);

// Anvil default accounts
const DEPLOYER_PK = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" as Hex;
const SELLER_PK = "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d" as Hex; // Account #1
const BUYER_PK = "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a" as Hex;  // Account #2

// Contract addresses (from deployment)
const TOKEN_ADDRESS = "0x5FbDB2315678afecb367f032d93F642f64180aa3" as Address;
const NFT_ADDRESS = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512" as Address;
const MARKET_ADDRESS = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0" as Address;

const RPC_URL = "http://127.0.0.1:8545";
const NFT_PRICE = BigInt("100000000000000000000"); // 100 tokens

async function main() {
    console.log("╔════════════════════════════════════════════════════════════╗");
    console.log("║       AirdopMerkleNFTMarket Demo Flow                      ║");
    console.log("╚════════════════════════════════════════════════════════════╝\n");

    // Create clients
    const publicClient = createPublicClient({
        chain: foundry,
        transport: http(RPC_URL),
    });

    const deployerAccount = privateKeyToAccount(DEPLOYER_PK);
    const sellerAccount = privateKeyToAccount(SELLER_PK);
    const buyerAccount = privateKeyToAccount(BUYER_PK);

    const deployerWallet = createWalletClient({
        account: deployerAccount,
        chain: foundry,
        transport: http(RPC_URL),
    });

    const sellerWallet = createWalletClient({
        account: sellerAccount,
        chain: foundry,
        transport: http(RPC_URL),
    });

    const buyerWallet = createWalletClient({
        account: buyerAccount,
        chain: foundry,
        transport: http(RPC_URL),
    });

    console.log("📋 Accounts:");
    console.log(`   Deployer: ${deployerAccount.address}`);
    console.log(`   Seller:   ${sellerAccount.address}`);
    console.log(`   Buyer:    ${buyerAccount.address} (whitelisted)`);
    console.log();

    // ========== Step 1: Transfer tokens to buyer ==========
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("📦 Step 1: Transfer tokens to buyer");
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    
    const transferAmount = BigInt("1000000000000000000000"); // 1000 tokens
    
    const transferHash = await deployerWallet.writeContract({
        address: TOKEN_ADDRESS,
        abi: TOKEN_ABI,
        functionName: "transfer",
        args: [buyerAccount.address, transferAmount],
    });
    await publicClient.waitForTransactionReceipt({ hash: transferHash });
    
    const buyerBalance = await publicClient.readContract({
        address: TOKEN_ADDRESS,
        abi: TOKEN_ABI,
        functionName: "balanceOf",
        args: [buyerAccount.address],
    });
    console.log(`   ✅ Transferred ${formatEther(transferAmount)} tokens to buyer`);
    console.log(`   📊 Buyer token balance: ${formatEther(buyerBalance)} tokens`);
    console.log();

    // ========== Step 2: Mint NFT to seller ==========
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("🎨 Step 2: Mint NFT to seller");
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    
    const mintHash = await deployerWallet.writeContract({
        address: NFT_ADDRESS,
        abi: NFT_ABI,
        functionName: "mint",
        args: [sellerAccount.address],
    });
    await publicClient.waitForTransactionReceipt({ hash: mintHash });
    
    const tokenId = BigInt(0); // First minted NFT
    const nftOwner = await publicClient.readContract({
        address: NFT_ADDRESS,
        abi: NFT_ABI,
        functionName: "ownerOf",
        args: [tokenId],
    });
    console.log(`   ✅ Minted NFT #${tokenId} to seller`);
    console.log(`   📊 NFT owner: ${nftOwner}`);
    console.log();

    // ========== Step 3: Seller approves and lists NFT ==========
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("📝 Step 3: Seller approves and lists NFT");
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    
    // Approve market
    const approveHash = await sellerWallet.writeContract({
        address: NFT_ADDRESS,
        abi: NFT_ABI,
        functionName: "setApprovalForAll",
        args: [MARKET_ADDRESS, true],
    });
    await publicClient.waitForTransactionReceipt({ hash: approveHash });
    console.log(`   ✅ Seller approved market for NFT`);
    
    // List NFT
    const listHash = await sellerWallet.writeContract({
        address: MARKET_ADDRESS,
        abi: MARKET_ABI,
        functionName: "list",
        args: [tokenId, NFT_PRICE],
    });
    await publicClient.waitForTransactionReceipt({ hash: listHash });
    
    const listing = await publicClient.readContract({
        address: MARKET_ADDRESS,
        abi: MARKET_ABI,
        functionName: "getListing",
        args: [tokenId],
    });
    console.log(`   ✅ NFT #${tokenId} listed for ${formatEther(NFT_PRICE)} tokens`);
    console.log(`   📊 Listing: seller=${listing[0]}, price=${formatEther(listing[1])}, active=${listing[2]}`);
    console.log();

    // ========== Step 4: Load merkle proof for buyer ==========
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("🌳 Step 4: Load Merkle proof for buyer");
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    
    const merkleDataPath = path.join(__dirname, "../merkle-data/merkle-tree.json");
    const merkleData = JSON.parse(fs.readFileSync(merkleDataPath, "utf-8"));
    const proof = merkleData.proofs[getAddress(buyerAccount.address)] as Hex[];
    
    if (!proof) {
        console.error(`   ❌ Address ${buyerAccount.address} is not in the whitelist!`);
        process.exit(1);
    }
    
    console.log(`   ✅ Buyer is whitelisted`);
    console.log(`   📊 Merkle proof: ${JSON.stringify(proof).slice(0, 80)}...`);
    console.log();

    // ========== Step 5: Execute multicall (permit + claim) ==========
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("🚀 Step 5: Execute multicall (permitPrePay + claimNFT)");
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    
    console.log(`   📊 Original price: ${formatEther(NFT_PRICE)} tokens`);
    console.log(`   📊 Discounted price (50% off): ${formatEther(NFT_PRICE / BigInt(2))} tokens`);
    console.log();
    
    // Build multicall data
    const multicallData = await buildMulticallData(
        publicClient,
        buyerWallet,
        TOKEN_ADDRESS,
        MARKET_ADDRESS,
        tokenId,
        proof
    );
    
    console.log(`   📦 Multicall data prepared`);
    console.log(`      Call 1 (permitPrePay): ${multicallData[0].slice(0, 40)}...`);
    console.log(`      Call 2 (claimNFT): ${multicallData[1].slice(0, 40)}...`);
    console.log();
    
    // Execute multicall
    const txHash = await executeMulticall(publicClient, buyerWallet, MARKET_ADDRESS, multicallData);
    
    // ========== Step 6: Verify results ==========
    console.log();
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("✅ Step 6: Verify results");
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    
    const newNftOwner = await publicClient.readContract({
        address: NFT_ADDRESS,
        abi: NFT_ABI,
        functionName: "ownerOf",
        args: [tokenId],
    });
    
    const sellerTokenBalance = await publicClient.readContract({
        address: TOKEN_ADDRESS,
        abi: TOKEN_ABI,
        functionName: "balanceOf",
        args: [sellerAccount.address],
    });
    
    const buyerFinalBalance = await publicClient.readContract({
        address: TOKEN_ADDRESS,
        abi: TOKEN_ABI,
        functionName: "balanceOf",
        args: [buyerAccount.address],
    });
    
    console.log(`   📊 NFT #${tokenId} new owner: ${newNftOwner}`);
    console.log(`   📊 Seller received: ${formatEther(sellerTokenBalance)} tokens`);
    console.log(`   📊 Buyer remaining balance: ${formatEther(buyerFinalBalance)} tokens`);
    console.log();
    
    console.log("╔════════════════════════════════════════════════════════════╗");
    console.log("║                    🎉 Demo Complete! 🎉                    ║");
    console.log("╚════════════════════════════════════════════════════════════╝");
    console.log();
    console.log(`Transaction hash: ${txHash}`);
}

main().catch(console.error);
