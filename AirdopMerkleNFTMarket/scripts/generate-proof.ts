/**
 * Generate Merkle Proof for a Specific Address
 *
 * Usage: npx ts-node scripts/generate-proof.ts <address>
 */

import { isAddress, getAddress } from "viem";
import * as fs from "fs";
import * as path from "path";

const MERKLE_DATA_PATH = path.join(__dirname, "../merkle-data/merkle-tree.json");

async function main() {
    const address = process.argv[2];

    if (!address) {
        console.error("Usage: npx ts-node scripts/generate-proof.ts <address>");
        process.exit(1);
    }

    if (!isAddress(address)) {
        console.error(`Invalid address: ${address}`);
        process.exit(1);
    }

    const normalizedAddress = getAddress(address);

    // Load merkle tree data
    if (!fs.existsSync(MERKLE_DATA_PATH)) {
        console.error("Merkle tree data not found. Run 'npm run build:tree' first.");
        process.exit(1);
    }

    const merkleData = JSON.parse(fs.readFileSync(MERKLE_DATA_PATH, "utf-8"));

    // Check if address is in whitelist
    if (!merkleData.proofs[normalizedAddress]) {
        console.log(`Address ${normalizedAddress} is NOT in the whitelist.`);
        process.exit(0);
    }

    const proof = merkleData.proofs[normalizedAddress];

    console.log(`\n=== Merkle Proof for ${normalizedAddress} ===\n`);
    console.log("Proof array:");
    console.log(JSON.stringify(proof, null, 2));

    console.log("\nFor Solidity (bytes32[]):");
    console.log(`[${proof.map((p: string) => `"${p}"`).join(", ")}]`);

    console.log("\nMerkle Root:");
    console.log(merkleData.root);
}

main().catch(console.error);
