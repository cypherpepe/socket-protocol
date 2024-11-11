// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAuctionHouse} from "../../../interfaces/IAuctionHouse.sol";
import {IAppGateway} from "../../../interfaces/IAppGateway.sol";
import {BatchDeployerModule} from "./BatchDeployerModule.sol";
import {Ownable} from "../../../utils/Ownable.sol";
import {IAddressResolver} from "../../../interfaces/IAddressResolver.sol";
import {Bid, PayloadBatch, FeesData, PayloadDetails, FinalizeParams, NextFunctionInfo} from "../../../common/Structs.sol";
import {FORWARD_CALL, DISTRIBUTE_FEE, DEPLOY, WITHDRAW} from "../../../common/Constants.sol";

// msg.sender map and call next function flow
abstract contract PayloadDeliveryModule is
    BatchDeployerModule,
    Ownable(msg.sender)
{
    uint256 public payloadBatchCounter;

    mapping(bytes32 => Bid) public winningBids;
    // payloadBatchHash => auction status
    mapping(bytes32 => bool) public auctionClosed;
    uint256 public feesCounter;

    // payloadBatchHash => PayloadBatch
    mapping(bytes32 => PayloadBatch) public payloadBatches;
    // payloadBatchHash => totalPayloadsRemaining
    mapping(bytes32 => uint256) public totalPayloadsRemaining;
    // payloadBatchHash => PayloadDetails[]
    mapping(bytes32 => PayloadDetails[]) public payloadDetailsArrays;
    // payloadId => payloadBatchHash
    mapping(bytes32 => bytes32) public payloadIdToBatchHash;
    mapping(uint32 => uint256) public feeCollectionGasLimit;

    error AllPayloadsExecuted();
    error NotFromForwarder();
    event PayloadSubmitted(
        bytes32 indexed payloadBatchHash,
        address indexed appGateway,
        PayloadDetails[] payloads,
        FeesData feesData,
        uint256 auctionEndDelay
    );

    event PayloadFinalizeRequested(
        bytes32 indexed payloadBatchHash,
        bytes32 indexed payloadId,
        bytes32 indexed root,
        PayloadDetails payloadDetails
    );
    error CallFailed(bytes32 payloadId);

    constructor(
        address addressResolver_
    ) BatchDeployerModule(addressResolver_) {
        feeCollectionGasLimit[421614] = 2000000;
        feeCollectionGasLimit[11155420] = 1000000;
    }

    function setFeeCollectionGasLimits(
        uint32[] memory chainSlugs,
        uint256[] memory gasLimits
    ) external {
        require(
            chainSlugs.length == gasLimits.length,
            "Input arrays must have the same length"
        );

        for (uint256 i = 0; i < chainSlugs.length; i++) {
            feeCollectionGasLimit[chainSlugs[i]] = gasLimits[i];
        }
    }

    function deliverPayload(
        PayloadDetails[] memory payloadDetails_,
        FeesData memory feesData_,
        uint256 auctionEndDelayMS_,
        bool sequentialProcessing_,
        bytes memory postBatchExecutedData_
    ) public override returns (bytes32) {
        address forwarderAppGateway = msg.sender;
        for (uint256 i = 0; i < payloadDetails_.length; i++) {
            bytes memory newPayload;

            if (payloadDetails_[i].target == address(0)) {
                newPayload = abi.encode(DEPLOY, payloadDetails_[i].payload);
            } else {
                forwarderAppGateway = IAddressResolver(addressResolver)
                    .contractsToGateways(msg.sender);
                if (forwarderAppGateway == address(0))
                    forwarderAppGateway = msg.sender;

                newPayload = abi.encode(
                    FORWARD_CALL,
                    abi.encode(
                        payloadDetails_[i].target,
                        payloadDetails_[i].payload
                    )
                );
            }

            payloadDetails_[i].payload = newPayload;
            payloadDetails_[i].target = getPayloadDeliveryPlugAddress(
                payloadDetails_[i].chainSlug
            );
        }
        bytes32 payloadBatchHash = keccak256(
            abi.encode(
                payloadDetails_,
                feesData_,
                auctionEndDelayMS_,
                payloadBatchCounter++
            )
        );

        payloadBatches[payloadBatchHash] = PayloadBatch({
            appGateway: forwarderAppGateway,
            feesData: feesData_,
            auctionEndDelayMS: auctionEndDelayMS_,
            currentPayloadIndex: 0,
            sequentialProcessing: sequentialProcessing_,
            postBatchExecutedData: postBatchExecutedData_
        });

        for (uint256 i = 0; i < payloadDetails_.length; i++) {
            payloadDetailsArrays[payloadBatchHash].push(payloadDetails_[i]);
        }
        emit PayloadSubmitted(
            payloadBatchHash,
            forwarderAppGateway,
            payloadDetails_,
            feesData_,
            auctionEndDelayMS_
        );
        totalPayloadsRemaining[payloadBatchHash] = payloadDetails_.length;
        return payloadBatchHash;
    }

    function _startBatchProcessing(bytes32 payloadBatchHash_) internal {
        PayloadBatch storage batch = payloadBatches[payloadBatchHash_];
        if (batch.sequentialProcessing) {
            _finalizeNextPayload(payloadBatchHash_);
        } else {
            uint256 totalPayloads = totalPayloadsRemaining[payloadBatchHash_];
            for (uint256 i = 0; i < totalPayloads; i++) {
                _finalizeNextPayload(payloadBatchHash_);
                batch.currentPayloadIndex++;
            }
        }
    }

    function callback(
        bytes32 payloadId_,
        bytes calldata returnData_
    ) external override onlyWatcher {
        bytes32 payloadBatchHash = payloadIdToBatchHash[payloadId_];
        PayloadBatch storage batch = payloadBatches[payloadBatchHash];
        PayloadDetails memory details = payloadDetailsArrays[payloadBatchHash][
            batch.currentPayloadIndex
        ];
        _callNextFunction(
            batch.appGateway,
            payloadBatchHash,
            details.isContractDeployment,
            details.next,
            returnData_
        );
        uint256 payloadsRemaining = totalPayloadsRemaining[payloadBatchHash];
        if (payloadsRemaining == 0) return;

        payloadsRemaining--;
        totalPayloadsRemaining[payloadBatchHash] = payloadsRemaining;

        if (payloadsRemaining == 0) {
            _createFeesSignature(
                batch.appGateway,
                batch.feesData,
                winningBids[payloadBatchHash]
            );

            IAppGateway(batch.appGateway).allPayloadsExecuted(
                payloadBatchHash,
                batch.postBatchExecutedData
            );
            return;
        }

        if (batch.sequentialProcessing) {
            batch.currentPayloadIndex++;
            _finalizeNextPayload(payloadBatchHash);
        }
    }

    function _finalizeNextPayload(bytes32 payloadBatchHash_) internal {
        PayloadBatch storage batch = payloadBatches[payloadBatchHash_];
        uint256 currentPayloadIndex = batch.currentPayloadIndex;
        PayloadDetails[] storage payloads = payloadDetailsArrays[
            payloadBatchHash_
        ];
        PayloadDetails storage payloadDetails = payloads[currentPayloadIndex];
        FinalizeParams memory finalizeParams = FinalizeParams({
            payloadDetails: payloadDetails,
            transmitter: winningBids[payloadBatchHash_].transmitter
        });
        (bytes32 payloadId, bytes32 root) = watcher().finalize(finalizeParams);
        payloadIdToBatchHash[payloadId] = payloadBatchHash_;
        emit PayloadFinalizeRequested(
            payloadBatchHash_,
            payloadId,
            root,
            payloadDetails
        );
    }

    function _callNextFunction(
        address appGateway_,
        bytes32 payloadBatchHash_,
        bool isContractDeployment_,
        NextFunctionInfo memory next_,
        bytes memory returnData_
    ) internal {
        if (isContractDeployment_) {
            setAddress(payloadBatchHash_, next_.data, returnData_);
        }

        if (next_.selector != bytes4(0)) {
            bytes memory calldata_ = abi.encodePacked(
                next_.selector,
                abi.encode(payloadBatchHash_, next_.data, returnData_)
            );
            (bool success, ) = appGateway_.call(calldata_);
            require(success, "Call failed");
        }
    }

    function _createFeesSignature(
        address appGateway_,
        FeesData memory feesData_,
        Bid memory winningBid_
    ) internal {
        // Create payload for pool contract
        bytes memory payload = abi.encode(
            DISTRIBUTE_FEE,
            abi.encode(
                appGateway_,
                feesData_.feePoolToken,
                winningBid_.fee,
                winningBid_.transmitter,
                feesCounter++
            )
        );

        PayloadDetails memory payloadDetails = PayloadDetails({
            chainSlug: feesData_.feePoolChain,
            target: getPayloadDeliveryPlugAddress(feesData_.feePoolChain),
            payload: payload,
            isContractDeployment: false,
            executionGasLimit: feeCollectionGasLimit[feesData_.feePoolChain],
            next: NextFunctionInfo({selector: bytes4(0), data: bytes("")})
        });

        FinalizeParams memory finalizeParams = FinalizeParams({
            payloadDetails: payloadDetails,
            transmitter: winningBid_.transmitter
        });

        watcher().finalize(finalizeParams);
    }

    function getPayloadDeliveryPlugAddress(
        uint32 chainSlug_
    ) public view returns (address) {
        return watcher().appGatewayPlugs(address(this), chainSlug_);
    }
}
