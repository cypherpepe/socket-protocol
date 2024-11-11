// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "../../../base/AppGatewayBase.sol";
import {ISuperToken} from "../../../interfaces/ISuperToken.sol";

contract SuperTokenApp is AppGatewayBase {
    struct UserOrder {
        address srcToken;
        address dstToken;
        address user;
        uint256 srcAmount;
        uint256 deadline;
    }

    constructor(
        address _addressResolver,
        FeesData memory feesData_,
        address deployerContract_
    ) AppGatewayBase(_addressResolver, feesData_) Ownable(msg.sender) {
        addressResolver.setContractsToGateways(deployerContract_);
    }

    function bridge(bytes memory _order) external queueAndExecute {
        UserOrder memory order = abi.decode(_order, (UserOrder));

        ISuperToken(order.srcToken).burn(order.user, order.srcAmount);
        ISuperToken(order.dstToken).mint(order.user, order.srcAmount);
    }
}
