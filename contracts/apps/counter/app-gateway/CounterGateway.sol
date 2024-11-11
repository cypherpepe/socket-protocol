// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../../../base/AppGatewayBase.sol";
import "../CounterPlug.sol";

contract CounterGateway is AppGatewayBase {
    constructor(
        address _addressResolver,
        address deployerContract_,
        FeesData memory feesData_
    ) AppGatewayBase(_addressResolver, feesData_) Ownable(msg.sender) {
        addressResolver.setContractsToGateways(deployerContract_);
    }

    function incrementCounter(address _instance) public queueAndExecute {
        CounterPlug(_instance).increase();
    }
}
