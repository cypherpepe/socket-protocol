import { Contract, Signer, Wallet, providers } from "ethers";
import { DeployParams, getOrDeploy, storeAddresses } from "./utils";
import {
  ChainSlug,
  ChainSocketAddresses,
  CORE_CONTRACTS,
  DeploymentAddresses,
  DeploymentMode,
} from "@socket.tech/dl-core";
import { getProviderFromChainSlug } from "../constants";
import { ethers } from "hardhat";
import dev_addresses from "../../deployments/dev_addresses.json";
import {
  AppContracts,
  WatcherVMCoreContracts,
  chains,
  socketOwner,
  watcher,
} from "./config";
import SuperToken from "../../out/SuperToken.sol/SuperToken.json";
import LimitHook from "../../out/LimitHook.sol/LimitHook.json";
import SuperTokenDeployer from "../../out/SuperTokenDeployer.sol/SuperTokenDeployer.json";
import { ETH_ADDRESS, feesData, MAX_FEES } from "../constants/constants";

const main = async () => {
  try {
    let addresses: DeploymentAddresses;
    let deployUtils: DeployParams = {
      addresses: {} as ChainSocketAddresses,
      mode: DeploymentMode.DEV,
      signer: new ethers.Wallet(process.env.SOCKET_SIGNER_KEY as string),
      currentChainSlug: 3605 as ChainSlug,
    };
    try {
      console.log("Deploying Socket contracts");
      addresses = dev_addresses as unknown as DeploymentAddresses;
      for (const chain of chains) {
        try {
          let chainAddresses: ChainSocketAddresses = addresses[chain]
            ? (addresses[chain] as ChainSocketAddresses)
            : ({} as ChainSocketAddresses);

          const providerInstance = getProviderFromChainSlug(chain);
          const signer: Wallet = new ethers.Wallet(
            process.env.SOCKET_SIGNER_KEY as string,
            providerInstance
          );
          const socketOwner = signer.address;

          deployUtils = {
            addresses: chainAddresses,
            mode: DeploymentMode.DEV,
            signer: signer,
            currentChainSlug: chain as ChainSlug,
          };

          const signatureVerifier: Contract = await getOrDeploy(
            CORE_CONTRACTS.SignatureVerifier,
            "contracts/socket/utils/SignatureVerifier.sol",
            [socketOwner],
            deployUtils
          );
          deployUtils.addresses[CORE_CONTRACTS.SignatureVerifier] =
            signatureVerifier.address;

          const hasher: Contract = await getOrDeploy(
            CORE_CONTRACTS.Hasher,
            "contracts/socket/utils/Hasher.sol",
            [socketOwner],
            deployUtils
          );
          deployUtils.addresses[CORE_CONTRACTS.Hasher] = hasher.address;

          const socket: Contract = await getOrDeploy(
            "Socket",
            "contracts/socket/Socket.sol",
            [chain as ChainSlug, hasher.address, socketOwner, "BROKEN_LEG"],
            deployUtils
          );
          deployUtils.addresses[CORE_CONTRACTS.Socket] = socket.address;

          const tm: Contract = await getOrDeploy(
            "TransmitManager",
            "contracts/socket/TransmitManager.sol",
            [
              chain as ChainSlug,
              signer.address,
              hasher.address,
              signatureVerifier.address,
              socket.address,
            ],
            deployUtils
          );
          deployUtils.addresses[CORE_CONTRACTS.TransmitManager] = tm.address;

          const sb: Contract = await getOrDeploy(
            "FastSwitchboard",
            "contracts/socket/switchboard/FastSwitchboard.sol",
            [
              chain as ChainSlug,
              socket.address,
              signatureVerifier.address,
              signer.address,
            ],
            deployUtils
          );
          deployUtils.addresses[CORE_CONTRACTS.FastSwitchboard] = sb.address;

          const auctionHousePlug: Contract = await getOrDeploy(
            "PayloadDeliveryPlug",
            "contracts/apps/payload-delivery/PayloadDeliveryPlug.sol",
            [chainAddresses[CORE_CONTRACTS.Socket], chain, signer.address],
            deployUtils
          );
          deployUtils.addresses["PayloadDeliveryPlug"] =
            auctionHousePlug.address;

          deployUtils.addresses.startBlock = deployUtils.addresses.startBlock
            ? deployUtils.addresses.startBlock
            : await deployUtils.signer.provider?.getBlockNumber();

          await storeAddresses(
            deployUtils.addresses,
            chain,
            DeploymentMode.DEV
          );
        } catch (error) {
          await storeAddresses(
            deployUtils.addresses,
            chain,
            DeploymentMode.DEV
          );
          console.log("Error:", error);
        }
      }
    } catch (error) {
      console.error("Error in main deployment:", error);
    }

    await deployWatcherVMContracts();
  } catch (error) {
    console.error("Error in overall deployment process:", error);
  }
};

async function updateContractSettings(
  contract: Contract,
  getterMethod: string,
  setterMethod: string,
  requiredAddress: string,
  signer: Signer
) {
  const currentValue = await contract.connect(signer)[getterMethod]();
  console.log({ current: currentValue, required: requiredAddress });

  if (currentValue.toLowerCase() !== requiredAddress.toLowerCase()) {
    const tx = await contract.connect(signer)[setterMethod](requiredAddress);
    console.log(`Setting ${getterMethod} for ${contract.address} to`, tx.hash);
    await tx.wait();
  }
}

const deployWatcherVMContracts = async () => {
  try {
    let addresses: DeploymentAddresses;
    let deployUtils: DeployParams = {
      addresses: {} as ChainSocketAddresses,
      mode: DeploymentMode.DEV,
      signer: new ethers.Wallet(process.env.SOCKET_SIGNER_KEY as string),
      currentChainSlug: 3605 as ChainSlug,
    };
    const chain = 3605;
    try {
      console.log("Deploying Watcher contracts");
      addresses = dev_addresses as unknown as DeploymentAddresses;
      let chainAddresses: ChainSocketAddresses = addresses[chain]
        ? (addresses[chain] as ChainSocketAddresses)
        : ({} as ChainSocketAddresses);

      const providerInstance = new providers.StaticJsonRpcProvider(
        process.env.WATCHER_VM_RPC_URL as string
      );
      const signer: Wallet = new ethers.Wallet(
        process.env.WATCHER_PRIVATE_KEY as string,
        providerInstance
      );
      const socketOwner = signer.address;

      deployUtils = {
        addresses: chainAddresses,
        mode: DeploymentMode.DEV,
        signer: signer,
        currentChainSlug: chain as ChainSlug,
      };
      let contractName: string = WatcherVMCoreContracts.Watcher;
      let watcherContract: Contract = await getOrDeploy(
        contractName,
        `contracts/watcher/${contractName}.sol`,
        [watcher],
        deployUtils
      );
      deployUtils.addresses[contractName] = watcherContract.address;

      contractName = WatcherVMCoreContracts.AddressResolver;
      let addressResolverContract: Contract = await getOrDeploy(
        contractName,
        `contracts/${contractName}.sol`,
        [watcher, deployUtils.addresses[WatcherVMCoreContracts.Watcher]],
        deployUtils
      );
      deployUtils.addresses[contractName] = addressResolverContract.address;

      contractName = WatcherVMCoreContracts.AuctionHouse;
      let auctionHouseContract: Contract = await getOrDeploy(
        contractName,
        `contracts/apps/payload-delivery/app-gateway/${contractName}.sol`,
        [deployUtils.addresses[WatcherVMCoreContracts.AddressResolver]],
        deployUtils
      );
      deployUtils.addresses[contractName] = auctionHouseContract.address;

      await updateContractSettings(
        addressResolverContract,
        "auctionHouse",
        "setAuctionHouse",
        auctionHouseContract.address,
        deployUtils.signer
      );

      deployUtils = await deploySuperTokenAppContracts(deployUtils, signer);

      deployUtils.addresses.startBlock = deployUtils.addresses.startBlock
        ? deployUtils.addresses.startBlock
        : await deployUtils.signer.provider?.getBlockNumber();

      await storeAddresses(
        deployUtils.addresses,
        chain as ChainSlug,
        DeploymentMode.DEV
      );
    } catch (error) {
      // await storeAddresses(
      //   deployUtils.addresses,
      //   chain as ChainSlug,
      //   DeploymentMode.DEV
      // );
      console.log("Error:", error);
    }
  } catch (error) {
    console.log("Error:", error);
  }
};

const deploySuperTokenAppContracts = async (
  deployUtils: DeployParams,
  signer: Wallet
) => {
  let contractName = AppContracts.SuperTokenDeployer;
  let superTokenDeployer: Contract = await getOrDeploy(
    contractName,
    `contracts/apps/super-token/app-gateway/${contractName}.sol`,
    [
      deployUtils.addresses[WatcherVMCoreContracts.AddressResolver],
      signer.address,
      ethers.utils.parseEther("10000"), // burnLimit
      ethers.utils.parseEther("10000"), // mintLimit
      "SUPER TOKEN", // name
      "SUPER", // symbol
      18, // decimals
      signer.address, // initialSupplyHolder
      ethers.utils.parseEther("1000000000"), // initialSupply
      feesData,
    ],
    deployUtils
  );
  deployUtils.addresses[contractName] = superTokenDeployer.address;

  contractName = AppContracts.SuperTokenApp;
  let superTokenApp: Contract = await getOrDeploy(
    contractName,
    `contracts/apps/super-token/app-gateway/${contractName}.sol`,
    [
      deployUtils.addresses[WatcherVMCoreContracts.AddressResolver],
      feesData,
      superTokenDeployer.address,
    ],
    deployUtils
  );
  deployUtils.addresses[contractName] = superTokenApp.address;

  return deployUtils;
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
