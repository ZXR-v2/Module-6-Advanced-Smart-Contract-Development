/**
 * Merkle Tree Builder for Whitelist
 *
 * This script builds a Merkle tree from a list of whitelisted addresses
 * and generates proofs for verification.
 */

import { keccak256, encodeAbiParameters, parseAbiParameters, isAddress, getAddress, concat, toHex } from "viem";
import * as fs from "fs";
import * as path from "path";

// Configuration
const OUTPUT_DIR = path.join(__dirname, "../merkle-data");

/**
 * Hash a leaf node using double keccak256 (OpenZeppelin standard)
 * This matches: keccak256(bytes.concat(keccak256(abi.encode(address))))
 */
function hashLeaf(address: `0x${string}`): `0x${string}` {
    // First encode the address (abi.encode pads to 32 bytes)
    const encoded = encodeAbiParameters(parseAbiParameters("address"), [address]);
    // First keccak256
    const firstHash = keccak256(encoded);
    // Second keccak256 (bytes.concat just concatenates)
    const secondHash = keccak256(firstHash);
    return secondHash;
}

/**
 * Sort and hash two nodes (for Merkle tree construction)
 */
function hashPair(a: `0x${string}`, b: `0x${string}`): `0x${string}` {
    // Sort pairs (OpenZeppelin MerkleProof uses sorted pairs)
    const sorted = BigInt(a) < BigInt(b) ? [a, b] : [b, a];
    return keccak256(concat(sorted));
}

/**
 * Build Merkle tree from whitelist addresses
 */
function buildMerkleTree(addresses: string[]): {
    root: `0x${string}`;
    leaves: { address: string; leaf: `0x${string}` }[];
    tree: `0x${string}`[][];
} {
    // Validate and normalize addresses
    const validAddresses = addresses.map((addr) => {
        if (!isAddress(addr)) {
            throw new Error(`Invalid address: ${addr}`);
        }
        return getAddress(addr);
    });

    // Create leaves
    const leaves = validAddresses.map((address) => ({
        address,
        leaf: hashLeaf(address),
    }));

    // Sort leaves for consistent tree structure
    const sortedLeaves = [...leaves].sort((a, b) =>
        BigInt(a.leaf) < BigInt(b.leaf) ? -1 : 1
    );

    // Build tree levels
    const tree: `0x${string}`[][] = [sortedLeaves.map((l) => l.leaf)];

    let currentLevel = tree[0];
    while (currentLevel.length > 1) {
        const nextLevel: `0x${string}`[] = [];
        for (let i = 0; i < currentLevel.length; i += 2) {
            if (i + 1 < currentLevel.length) {
                nextLevel.push(hashPair(currentLevel[i], currentLevel[i + 1]));
            } else {
                // Odd number of nodes, promote the last one
                nextLevel.push(currentLevel[i]);
            }
        }
        tree.push(nextLevel);
        currentLevel = nextLevel;
    }

    return {
        root: currentLevel[0],
        leaves,
        tree,
    };
}

/**
 * Generate proof for a specific address
 */
function generateProof(
    tree: `0x${string}`[][],
    leaf: `0x${string}`
): `0x${string}`[] {
    const proof: `0x${string}`[] = [];
    let index = tree[0].indexOf(leaf);

    if (index === -1) {
        // Try to find by hash comparison
        index = tree[0].findIndex((l) => l.toLowerCase() === leaf.toLowerCase());
        if (index === -1) {
            return [];
        }
    }

    for (let level = 0; level < tree.length - 1; level++) {
        const currentLevel = tree[level];
        const isRightNode = index % 2 === 1;
        const siblingIndex = isRightNode ? index - 1 : index + 1;

        if (siblingIndex < currentLevel.length) {
            proof.push(currentLevel[siblingIndex]);
        }

        index = Math.floor(index / 2);
    }

    return proof;
}

/**
 * Verify a proof
 */
function verifyProof(
    leaf: `0x${string}`,
    proof: `0x${string}`[],
    root: `0x${string}`
): boolean {
    let computedHash = leaf;

    for (const proofElement of proof) {
        computedHash = hashPair(computedHash, proofElement);
    }

    return computedHash.toLowerCase() === root.toLowerCase();
}

/**
 * Main function - build tree and save data
 */
async function main() {
    // Example whitelist addresses (replace with actual addresses)
    const whitelist = [
        "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
        "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
        "0x90F79bf6EB2c4f870365E785982E1f101E93b906",
        "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65",
        "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc",
    ];

    console.log("Building Merkle Tree...\n");
    console.log("Whitelist addresses:");
    whitelist.forEach((addr, i) => console.log(`  ${i + 1}. ${addr}`));

    const { root, leaves, tree } = buildMerkleTree(whitelist);

    console.log("\n=== Merkle Tree Info ===");
    console.log(`Root: ${root}`);
    console.log(`Total leaves: ${leaves.length}`);

    // Generate proofs for all addresses
    const proofs: { [address: string]: `0x${string}`[] } = {};
    leaves.forEach(({ address, leaf }) => {
        proofs[address] = generateProof(tree, leaf);
    });

    // Verify all proofs
    console.log("\n=== Proof Verification ===");
    leaves.forEach(({ address, leaf }) => {
        const proof = proofs[address];
        const isValid = verifyProof(leaf, proof, root);
        console.log(`${address}: ${isValid ? "✓ Valid" : "✗ Invalid"}`);
    });

    // Create output directory
    if (!fs.existsSync(OUTPUT_DIR)) {
        fs.mkdirSync(OUTPUT_DIR, { recursive: true });
    }

    // Save data
    const outputData = {
        root,
        whitelist: leaves,
        proofs,
        generatedAt: new Date().toISOString(),
    };

    const outputPath = path.join(OUTPUT_DIR, "merkle-tree.json");
    fs.writeFileSync(outputPath, JSON.stringify(outputData, null, 2));
    console.log(`\nMerkle tree data saved to: ${outputPath}`);

    // Print environment variable format
    console.log("\n=== For Deployment ===");
    console.log(`MERKLE_ROOT=${root}`);

    return outputData;
}

// Export functions for use in other scripts
export { buildMerkleTree, generateProof, verifyProof, hashLeaf };

// Run main if executed directly
main().catch(console.error);
