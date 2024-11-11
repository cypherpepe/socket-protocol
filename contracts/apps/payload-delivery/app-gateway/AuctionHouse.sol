// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAuctionHouse} from "../../../interfaces/IAuctionHouse.sol";
import {IAppGateway} from "../../../interfaces/IAppGateway.sol";
import {PayloadDeliveryModule} from "./PayloadDeliveryModule.sol";
import {Ownable} from "../../../utils/Ownable.sol";
import {Bid, PayloadBatch, FeesData, PayloadDetails, FinalizeParams, NextFunctionInfo} from "../../../common/Structs.sol";
import {FORWARD_CALL, DISTRIBUTE_FEE, DEPLOY, WITHDRAW} from "../../../common/Constants.sol";

// msg.sender map and call next function flow
contract AuctionHouse is PayloadDeliveryModule {
    constructor(
        address addressResolver_
    ) PayloadDeliveryModule(addressResolver_) {}

    function bid(bytes32 payloadBatchHash_, uint256 fee) external override {
        require(!auctionClosed[payloadBatchHash_], "Auction closed");

        Bid memory newBid = Bid({fee: fee, transmitter: msg.sender});
        PayloadBatch storage batch = payloadBatches[payloadBatchHash_];
        require(fee <= batch.feesData.maxFees, "Bid exceeds max fees");

        Bid memory oldBid = winningBids[payloadBatchHash_];

        if (oldBid.transmitter != address(0)) {
            require(newBid.fee < oldBid.fee, "Bid is not better");
        }

        winningBids[payloadBatchHash_] = newBid;
        emit BidPlaced(payloadBatchHash_, newBid);

        watcher().setTimeout(
            abi.encodeWithSelector(this.endAuction.selector, payloadBatchHash_),
            batch.auctionEndDelayMS
        );
    }

    function endAuction(bytes32 payloadBatchHash_) external onlyWatcher {
        auctionClosed[payloadBatchHash_] = true;
        Bid memory winningBid = winningBids[payloadBatchHash_];
        emit AuctionEnded(payloadBatchHash_, winningBid);

        _startBatchProcessing(payloadBatchHash_);
    }

    function withdrawTo(
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        address receiver_,
        FeesData memory feesData_
    ) external {
        address appGateway_ = msg.sender;
        // Create payload for pool contract
        bytes memory payload = abi.encode(
            WITHDRAW,
            abi.encode(appGateway_, token_, amount_, receiver_)
        );
        PayloadDetails[] memory payloadDetailsArray = new PayloadDetails[](1);
        payloadDetailsArray[0] = PayloadDetails({
            chainSlug: chainSlug_,
            target: getPayloadDeliveryPlugAddress(chainSlug_),
            payload: payload,
            isContractDeployment: false,
            executionGasLimit: feeCollectionGasLimit[chainSlug_],
            next: NextFunctionInfo({selector: bytes4(0), data: bytes("")})
        });

        deliverPayload(payloadDetailsArray, feesData_, 0, false, "");
    }
}
