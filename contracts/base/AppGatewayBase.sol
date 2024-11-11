// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "../utils/AddressResolverUtil.sol";
import "../interfaces/IAuctionHouse.sol";
import "../interfaces/IAppGateway.sol";
import {FeesData} from "../common/Structs.sol";
import {FeesPlugin} from "../utils/FeesPlugin.sol";
import "../utils/Ownable.sol";

abstract contract AppGatewayBase is
    AddressResolverUtil,
    IAppGateway,
    FeesPlugin,
    Ownable
{
    modifier queueAndExecute() {
        auctionHouse().clearQueue();
        _;
        auctionHouse().executeBatch(feesData, 0, true, "");
    }

    constructor(
        address _addressResolver,
        FeesData memory feesData_
    ) AddressResolverUtil(_addressResolver) FeesPlugin(feesData_) {}

    function withdrawFeeTokens(
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        address receiver_
    ) external onlyOwner {
        auctionHouse().withdrawTo(
            chainSlug_,
            token_,
            amount_,
            receiver_,
            feesData
        );
    }

    function callback(
        bytes32 payloadId_,
        bytes calldata returnData_
    ) external virtual {}

    function allPayloadsExecuted(
        bytes32 payloadBatchHash_,
        bytes calldata postBatchExecutedData_
    ) external virtual {}
}
