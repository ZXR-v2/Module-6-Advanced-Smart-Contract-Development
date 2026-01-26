/**
 * Multicall Helper for AirdopMerkleNFTMarket
 *
 * This script demonstrates how to construct multicall data
 * for permitPrePay + claimNFT operations.
 */

import {
    createPublicClient,
    createWalletClient,
    http,
    parseAbi,
    encodeFunctionData,
    formatEther,
    getAddress,
    type Address,
    type Hex,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { foundry } from "viem/chains";
import * as fs from "fs";
import * as path from "path";

// ABI fragments for the functions we need
const MARKET_ABI = parseAbi([
    "function permitPrePay(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)",
    "function claimNFT(uint256 tokenId, bytes32[] calldata merkleProof)",
    "function multicall(bytes[] calldata data) returns (bytes[] memory results)",
    "function getDiscountedPrice(uint256 tokenId) view returns (uint256)",
]);

const TOKEN_ABI = parseAbi([
    "function DOMAIN_SEPARATOR() view returns (bytes32)",
    "function nonces(address owner) view returns (uint256)",
    "function name() view returns (string)",
]);

/**
 * Generate EIP-2612 permit signature using viem
 */
async function generatePermitSignature(
    walletClient: ReturnType<typeof createWalletClient>,
    tokenAddress: Address,
    tokenName: string,
    spender: Address,
    value: bigint,
    nonce: bigint,
    deadline: bigint
): Promise<{ v: number; r: Hex; s: Hex }> {
    const account = walletClient.account!;

    const signature = await walletClient.signTypedData({
        account,
        domain: {
            name: tokenName,
            version: "1",
            chainId: walletClient.chain?.id ?? 1,
            verifyingContract: tokenAddress,
        },
        types: {
            Permit: [
                { name: "owner", type: "address" },
                { name: "spender", type: "address" },
                { name: "value", type: "uint256" },
                { name: "nonce", type: "uint256" },
                { name: "deadline", type: "uint256" },
            ],
        },
        primaryType: "Permit",
        message: {
            owner: account.address,
            spender,
            value,
            nonce,
            deadline,
        },
    });

    // Parse signature
    const r = `0x${signature.slice(2, 66)}` as Hex;
    const s = `0x${signature.slice(66, 130)}` as Hex;
    const v = parseInt(signature.slice(130, 132), 16);

    return { v, r, s };
}

/**
 * Build multicall data for permit + claim
 */
async function buildMulticallData(
    publicClient: ReturnType<typeof createPublicClient>,
    walletClient: ReturnType<typeof createWalletClient>,
    tokenAddress: Address,
    marketAddress: Address,
    tokenId: bigint,
    merkleProof: Hex[]
): Promise<Hex[]> {
    const account = walletClient.account!;

    // Get discounted price
    const discountedPrice = await publicClient.readContract({
        address: marketAddress,
        abi: MARKET_ABI,
        functionName: "getDiscountedPrice",
        args: [tokenId],
    });
    console.log(`Discounted price for token ${tokenId}: ${formatEther(discountedPrice)} ETH`);

    // Get token name and nonce
    const [tokenName, nonce] = await Promise.all([
        publicClient.readContract({
            address: tokenAddress,
            abi: TOKEN_ABI,
            functionName: "name",
        }),
        publicClient.readContract({
            address: tokenAddress,
            abi: TOKEN_ABI,
            functionName: "nonces",
            args: [account.address],
        }),
    ]);

    // Set deadline to 1 hour from now
    const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600);

    // Generate permit signature
    const { v, r, s } = await generatePermitSignature(
        walletClient,
        tokenAddress,
        tokenName,
        marketAddress,
        discountedPrice,
        nonce,
        deadline
    );

    // Encode permitPrePay call
    const permitPrePayData = encodeFunctionData({
        abi: MARKET_ABI,
        functionName: "permitPrePay",
        args: [account.address, marketAddress, discountedPrice, deadline, v, r, s],
    });

    // Encode claimNFT call
    const claimNFTData = encodeFunctionData({
        abi: MARKET_ABI,
        functionName: "claimNFT",
        args: [tokenId, merkleProof],
    });

    return [permitPrePayData, claimNFTData];
}

/**
 * Execute multicall transaction
 */
async function executeMulticall(
    publicClient: ReturnType<typeof createPublicClient>,
    walletClient: ReturnType<typeof createWalletClient>,
    marketAddress: Address,
    multicallData: Hex[]
): Promise<Hex> {
    const account = walletClient.account!;

    console.log("\nExecuting multicall...");

    const hash = await walletClient.writeContract({
        account,
        chain: walletClient.chain,
        address: marketAddress,
        abi: MARKET_ABI,
        functionName: "multicall",
        args: [multicallData],
    });

    console.log(`Transaction hash: ${hash}`);

    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    console.log(`Transaction confirmed in block ${receipt.blockNumber}`);

    return hash;
}

/**
 * Example usage
 */
async function example() {
    // Configuration (replace with actual values)
    const RPC_URL = process.env.RPC_URL || "http://localhost:8545";
    const PRIVATE_KEY = process.env.PRIVATE_KEY || "";
    const TOKEN_ADDRESS = process.env.TOKEN_ADDRESS || "";
    const MARKET_ADDRESS = process.env.MARKET_ADDRESS || "";
    const TOKEN_ID = BigInt(process.env.TOKEN_ID || "0");

    if (!PRIVATE_KEY || !TOKEN_ADDRESS || !MARKET_ADDRESS) {
        console.log("=== Multicall Helper Example ===\n");
        console.log("This script demonstrates how to build and execute multicall transactions.");
        console.log("\nRequired environment variables:");
        console.log("  RPC_URL         - Ethereum RPC URL");
        console.log("  PRIVATE_KEY     - Private key of the buyer (with 0x prefix)");
        console.log("  TOKEN_ADDRESS   - Address of the PermitToken");
        console.log("  MARKET_ADDRESS  - Address of the AirdopMerkleNFTMarket");
        console.log("  TOKEN_ID        - NFT token ID to purchase");
        console.log("\nExample:");
        console.log("  RPC_URL=http://localhost:8545 \\");
        console.log("  PRIVATE_KEY=0x... \\");
        console.log("  TOKEN_ADDRESS=0x... \\");
        console.log("  MARKET_ADDRESS=0x... \\");
        console.log("  TOKEN_ID=0 \\");
        console.log("  npx ts-node scripts/multicall-helper.ts");
        return;
    }

    // Load merkle proof
    const merkleDataPath = path.join(__dirname, "../merkle-data/merkle-tree.json");
    if (!fs.existsSync(merkleDataPath)) {
        console.error("Merkle tree data not found. Run 'npm run build:tree' first.");
        process.exit(1);
    }

    // Create clients
    const account = privateKeyToAccount(PRIVATE_KEY as Hex);

    const publicClient = createPublicClient({
        chain: foundry,
        transport: http(RPC_URL),
    });

    const walletClient = createWalletClient({
        account,
        chain: foundry,
        transport: http(RPC_URL),
    });

    const merkleData = JSON.parse(fs.readFileSync(merkleDataPath, "utf-8"));
    const proof = merkleData.proofs[getAddress(account.address)] as Hex[];

    if (!proof) {
        console.error(`Address ${account.address} is not in the whitelist.`);
        process.exit(1);
    }

    console.log(`Buyer address: ${account.address}`);
    console.log(`Token ID: ${TOKEN_ID}`);
    console.log(`Merkle proof: ${JSON.stringify(proof)}`);

    // Build multicall data
    const multicallData = await buildMulticallData(
        publicClient,
        walletClient,
        TOKEN_ADDRESS as Address,
        MARKET_ADDRESS as Address,
        TOKEN_ID,
        proof
    );

    console.log("\n=== Multicall Data ===");
    console.log("Call 1 (permitPrePay):", multicallData[0]);
    console.log("Call 2 (claimNFT):", multicallData[1]);

    // Execute multicall
    await executeMulticall(publicClient, walletClient, MARKET_ADDRESS as Address, multicallData);

    console.log("\n=== Transaction Successful ===");
}

export { buildMulticallData, executeMulticall, generatePermitSignature };

example().catch(console.error);
