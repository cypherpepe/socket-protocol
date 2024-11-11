import fs from "fs";
import path from "path";
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import { config as dotenvConfig } from "dotenv";

import applicationGateway from "../../artifacts/abi/SuperTokenApp.json";
import transmitManager from "../../artifacts/abi/TransmitManager.json";
import ERC20 from "../../artifacts/abi/ERC20.json";
import auctionHouse from "../../artifacts/abi/AuctionHouse.json";
import auctionHousePlug from "../../artifacts/abi/PayloadDeliveryPlug.json";
import socket from "../../artifacts/abi/Socket.json";
import watcherVM from "../../artifacts/abi/Watcher.json";

export const applicationGatewayABI = applicationGateway;
export const transmitManagerABI = transmitManager;
export const ERC20ABI = ERC20;
export const auctionHouseABI = auctionHouse;
export const socketABI = socket;
export const watcherVMABI = watcherVM;
export const auctionHousePlugABI = auctionHousePlug;

const abis = {
  applicationGatewayABI,
  transmitManagerABI,
  ERC20ABI,
  auctionHouseABI,
  socketABI,
  watcherVMABI,
  auctionHousePlugABI,
};

dotenvConfig();

type ConfigEntry = {
  eventBlockRangePerCron: number;
  rpc: string | undefined;
  confirmations: number;
  eventBlockRange: number;
  addresses?: {
    SignatureVerifier: string;
    Hasher: string;
    Socket: string;
    TransmitManager: string;
    FastSwitchboard: string;
    SuperToken: string;
    PayloadDeliveryPlug: string;
    ConnectorPlug: string;
    startBlock: number;
  };
};

type S3Config = {
  [chainId: string]: ConfigEntry;
};
let config: S3Config = {
  "421614": {
    eventBlockRangePerCron: 5000,
    rpc: process.env.ARBITRUM_SEPOLIA_RPC,
    confirmations: 0,
    eventBlockRange: 5000,
  },
  "11155420": {
    eventBlockRangePerCron: 5000,
    rpc: process.env.OPTIMISM_SEPOLIA_RPC,
    confirmations: 0,
    eventBlockRange: 5000,
  },
  "3605": {
    eventBlockRangePerCron: 5000,
    rpc: process.env.WATCHER_VM_RPC_URL,
    confirmations: 0,
    eventBlockRange: 5000,
  },
  //@ts-ignore
  supportedChainSlugs: [421614, 11155420, 3605],
};
// Read the dev_addresses.json file
const devAddressesPath = path.join(
  __dirname,
  "../../deployments/dev_addresses.json"
);
const devAddresses = JSON.parse(fs.readFileSync(devAddressesPath, "utf8"));

// Update config with addresses
for (const chainId in config) {
  if (devAddresses[chainId]) {
    console.log(`Updating addresses for chainId ${chainId}`);
    config[chainId].addresses = devAddresses[chainId];
  }
}
console.log(JSON.stringify(config, null, 2));
// Initialize S3 client
const s3Client = new S3Client({ region: "us-east-1" }); // Replace with your preferred region

// Function to upload to S3
async function uploadToS3(data: any, fileName: string) {
  const params = {
    Bucket: "socketpoc",
    Key: fileName,
    Body: JSON.stringify(data, null, 2),
    ContentType: "application/json",
  };

  try {
    const command = new PutObjectCommand(params);
    await s3Client.send(command);
    console.log(`Successfully uploaded ${fileName} to S3`);
  } catch (error) {
    console.error(`Error uploading ${fileName} to S3:`, error);
  }
}

// Upload config to S3
uploadToS3(config, "pocConfig.json");
uploadToS3(abis, "pocABIs.json");
