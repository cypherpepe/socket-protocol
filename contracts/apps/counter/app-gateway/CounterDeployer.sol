// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../CounterPlug.sol";
import "../../../base/AppDeployerBase.sol";

contract CounterDeployer is AppDeployerBase {
    address public counterPlug;

    constructor(
        address addressResolver_,
        FeesData memory feesData_
    ) AppDeployerBase(addressResolver_, feesData_) Ownable(msg.sender) {
        counterPlug = address(new CounterPlug());
        creationCodeWithArgs[counterPlug] = type(CounterPlug).creationCode;
    }

    function deployContracts(
        uint32 chainSlug
    ) external queueAndDeploy(chainSlug) {
        _deploy(counterPlug);
    }

    function initialize(uint32 chainSlug) public override queueAndExecute {
        address payloadDeliveryPlug = addressResolver.watcher().appGatewayPlugs(
            addressResolver.auctionHouse(),
            chainSlug
        );

        CounterPlug(forwarderAddresses[counterPlug][chainSlug]).setSocket(
            payloadDeliveryPlug
        );
    }
}
