// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {PlugConfig, AppGatewayConfig} from "../common/Structs.sol";
import {IWatcher} from "./IWatcher.sol";

interface IAddressResolver {
    // View functions
    function auctionHouse() external view returns (address);

    function watcher() external view returns (IWatcher);

    function contractsToGateways(address) external view returns (address);

    function gatewaysToContracts(address) external view returns (address);

    function isRegisteredGateway(address) external view returns (bool);

    function getPlugConfigs(
        uint32,
        address
    ) external view returns (address, address);

    function appGatewayPlugs(address, uint32) external view returns (address);

    // State-changing functions
    function setAuctionHouse(address _auctionHouse) external;

    function setWatcher(address _watcher) external;

    function setAppGateways(AppGatewayConfig[] calldata configs) external;

    function setContractsToGateways(address contractAddress_) external;

    function deployForwarderContract(
        address appDeployer_,
        address chainContractAddress_,
        uint32 chainSlug_
    ) external returns (address);
}
