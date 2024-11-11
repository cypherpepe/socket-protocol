// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "solmate/utils/SafeTransferLib.sol";
import {ISocket} from "../../interfaces/ISocket.sol";
import {IPlug} from "../../interfaces/IPlug.sol";
import {Ownable} from "../../utils/Ownable.sol";
import {ContractFactory} from "./ContractFactory.sol";
import {FeesManager} from "./FeesManager.sol";
import {PlugBase} from "../../base/PlugBase.sol";
import {FORWARD_CALL, DISTRIBUTE_FEE, DEPLOY, ETH_ADDRESS, WITHDRAW} from "../../common/Constants.sol";
import {InvalidFunction} from "../../common/Errors.sol";

contract PayloadDeliveryPlug is ContractFactory, FeesManager, PlugBase {
    constructor(
        address socket_,
        uint32 chainSlug_,
        address owner_
    ) FeesManager() PlugBase(socket_, chainSlug_) {}

    function inbound(
        bytes calldata payload_
    ) external payable override onlySocket returns (bytes memory) {
        (bytes32 actionType, bytes memory data) = abi.decode(
            payload_,
            (bytes32, bytes)
        );

        if (actionType == FORWARD_CALL) {
            return _handleForwardCall(data);
        } else if (actionType == DEPLOY) {
            return _handleDeploy(data);
        } else if (actionType == DISTRIBUTE_FEE) {
            return _handleDistributeFee(data);
        } else if (actionType == WITHDRAW) {
            return _handleWithdraw(data);
        }
        revert InvalidFunction();
    }

    function _handleForwardCall(
        bytes memory data
    ) internal returns (bytes memory) {
        (address target, bytes memory forwardPayload) = abi.decode(
            data,
            (address, bytes)
        );
        (bool success, ) = target.call(forwardPayload);
        require(success, "PayloadDeliveryPlug: call failed");
        return bytes("");
    }
}
