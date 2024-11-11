// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "../interfaces/IAppGateway.sol";
import "../interfaces/IAddressResolver.sol";
import "../interfaces/IWatcher.sol";
import {Ownable} from "../utils/Ownable.sol";

abstract contract WatcherConfig is Ownable, IWatcher {
    // chainSlug => plug => appGateway
    mapping(uint32 => mapping(address => PlugConfig)) internal _plugConfigs;
    // appGateway => chainSlug => plug
    mapping(address => mapping(uint32 => address)) public appGatewayPlugs;

    event PlugAdded(address appGateway, uint32 chainSlug, address plug);

    function setAppGateways(
        AppGatewayConfig[] calldata configs
    ) external onlyOwner {
        for (uint256 i = 0; i < configs.length; i++) {
            _plugConfigs[configs[i].chainSlug][configs[i].plug] = PlugConfig({
                appGateway: configs[i].appGateway,
                switchboard: configs[i].switchboard
            });

            appGatewayPlugs[configs[i].appGateway][
                configs[i].chainSlug
            ] = configs[i].plug;

            emit PlugAdded(
                configs[i].appGateway,
                configs[i].chainSlug,
                configs[i].plug
            );
        }
    }

    function getPlugConfigs(
        uint32 chainSlug_,
        address plug_
    ) public view returns (address, address) {
        return (
            _plugConfigs[chainSlug_][plug_].appGateway,
            _plugConfigs[chainSlug_][plug_].switchboard
        );
    }
}
