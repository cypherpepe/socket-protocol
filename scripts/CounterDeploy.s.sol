// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Console.sol";
import {CounterGateway} from "../contracts/apps/counter/app-gateway/CounterGateway.sol";
import {CounterDeployer} from "../contracts/apps/counter/app-gateway/CounterDeployer.sol";
import {CounterPlug} from "../contracts/apps/counter/CounterPlug.sol";
import {FeesData} from "../contracts/common/Structs.sol";
import {ETH_ADDRESS} from "../contracts/common/Constants.sol";

contract CounterDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address addressResolver = 0x9798ea87BbEdB88fA44a62969b3afD11E52eE1A5;
        FeesData memory feesData = FeesData({
            feePoolChain: 421614,
            feePoolToken: ETH_ADDRESS,
            maxFees: 0.01 ether
        });

        CounterDeployer deployer = new CounterDeployer(
            addressResolver,
            feesData
        );

        CounterGateway gateway = new CounterGateway(
            addressResolver,
            address(deployer),
            feesData
        );

        console.log("Contracts deployed:");
        console.log("Deployer:", address(deployer));
        console.log("Gateway:", address(gateway));

        console.log("Deploying contracts on Arbitrum...");
        deployer.deployContracts(421614);

        console.log("Deploying contracts on Optimism...");
        deployer.deployContracts(11155420);
    }
}
