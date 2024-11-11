import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import "@typechain/hardhat";
import "hardhat-preprocessor";
import "hardhat-deploy";
import "hardhat-abi-exporter";
import "hardhat-change-network";

import { config as dotenvConfig } from "dotenv";
import type { HardhatUserConfig } from "hardhat/config";
import type {
  HardhatNetworkAccountUserConfig,
  NetworkUserConfig,
} from "hardhat/types";
import { resolve } from "path";
import fs from "fs";

import "./tasks/accounts";
import { getJsonRpcUrl } from "./scripts/constants/networks";
import {
  ChainId,
  ChainSlug,
  ChainSlugToId,
  HardhatChainName,
  hardhatChainNameToSlug,
} from "@socket.tech/dl-core";

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });

// Ensure that we have all the environment variables we need.
// TODO: fix it for setup scripts
// if (!process.env.SOCKET_SIGNER_KEY) throw new Error("No private key found");
const privateKey: HardhatNetworkAccountUserConfig = process.env
  .SOCKET_SIGNER_KEY as unknown as HardhatNetworkAccountUserConfig;

function getChainConfig(chainSlug: ChainSlug): NetworkUserConfig {
  return {
    accounts: [`0x${privateKey}`],
    chainId: ChainSlugToId[chainSlug],
    url: getJsonRpcUrl(chainSlug),
  };
}

function getRemappings() {
  return fs
    .readFileSync("remappings.txt", "utf8")
    .split("\n")
    .filter(Boolean) // remove empty lines
    .map((line) => line.trim().split("="));
}

let liveNetworks = {
  [HardhatChainName.ARBITRUM_SEPOLIA]: getChainConfig(
    ChainSlug.ARBITRUM_SEPOLIA
  ),
  [HardhatChainName.OPTIMISM_SEPOLIA]: getChainConfig(
    ChainSlug.OPTIMISM_SEPOLIA
  ),
  [HardhatChainName.SEPOLIA]: getChainConfig(ChainSlug.SEPOLIA),
  BROKEN_LEG: {
    accounts: [`0x${privateKey}`],
    chainId: 3605,
    url: process.env.BROKEN_LEG_RPC,
  },
};

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  abiExporter: {
    path: "artifacts/abi",
    flat: true,
  },
  networks: {
    hardhat: {
      chainId: hardhatChainNameToSlug[HardhatChainName.HARDHAT],
    },
    ...liveNetworks,
  },
  paths: {
    sources: "./contracts",
    cache: "./cache_hardhat",
    artifacts: "./artifacts",
  },
  etherscan: {
    apiKey: {
      arbitrumOne: process.env.ARBISCAN_API_KEY || "",
      arbitrumTestnet: process.env.ARBISCAN_API_KEY || "",
      bsc: process.env.BSCSCAN_API_KEY || "",
      bscTestnet: process.env.BSCSCAN_API_KEY || "",
      goerli: process.env.ETHERSCAN_API_KEY || "",
      mainnet: process.env.ETHERSCAN_API_KEY || "",
      sepolia: process.env.ETHERSCAN_API_KEY || "",
      optimisticEthereum: process.env.OPTIMISM_API_KEY || "",
      optimisticTestnet: process.env.OPTIMISM_API_KEY || "",
      brokenLeg: "none",
    },
    customChains: [
      {
        network: "optimisticTestnet",
        chainId: ChainId.OPTIMISM_SEPOLIA,
        urls: {
          apiURL: "https://api-sepolia-optimistic.etherscan.io/api",
          browserURL: "https://sepolia-optimism.etherscan.io/",
        },
      },
      {
        network: "arbitrumTestnet",
        chainId: ChainId.ARBITRUM_SEPOLIA,
        urls: {
          apiURL: "https://api-sepolia.arbiscan.io/api",
          browserURL: "https://sepolia.arbiscan.io/",
        },
      },
      {
        network: "brokenLeg",
        chainId: 3605,
        urls: {
          apiURL:
            "https://explorer-cloud-broken-leg-7uu20euqoj.t.conduit.xyz/api",
          browserURL:
            "https://explorer-cloud-broken-leg-7uu20euqoj.t.conduit.xyz",
        },
      },
    ],
  },
  // This fully resolves paths for imports in the ./lib directory for Hardhat
  preprocess: {
    eachLine: (hre) => ({
      transform: (line: string) => {
        if (line.match(/^\s*import /i)) {
          getRemappings().forEach(([find, replace]) => {
            if (line.match(find)) {
              line = line.replace(find, replace);
            }
          });
        }
        return line;
      },
    }),
  },
  solidity: {
    version: "0.8.13",
    settings: {
      optimizer: {
        enabled: true,
        runs: 999999,
      },
    },
  },
};

export default config;
