// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;
import {PayloadDetails, Bid, FeesData, DeployParams} from "../common/Structs.sol";

interface IAuctionHouse {
    event BidPlaced(
        bytes32 indexed payloadBatchHash,
        Bid bid // Replaced transmitter and bidAmount with Bid struct
    );

    event AuctionEnded(
        bytes32 indexed payloadBatchHash,
        Bid winningBid // Replaced winningTransmitter and winningBid with Bid struct
    );

    function deliverPayload(
        PayloadDetails[] memory payloadDetails_,
        FeesData memory feesData_,
        uint256 auctionEndDelayMS_,
        bool sequential_,
        bytes memory postBatchExecutedData_
    ) external returns (bytes32);

    function clearQueue() external;

    function clearDeployQueue() external;

    function bid(bytes32 payloadBatchHash_, uint256 fee) external;

    function callback(bytes32 payloadId, bytes calldata returnData_) external;

    function queue(
        uint32 chainSlug_,
        address target_,
        bytes memory payload_
    ) external;

    function executeBatch(
        FeesData memory feesData_,
        uint256 auctionEndDelayMS_,
        bool sequentialProcessing_,
        bytes memory postBatchExecutedData_
    ) external returns (bytes32);

    function queueDeploy(DeployParams calldata deployParams) external;

    function deployBatch(
        uint32 chainSlug_,
        FeesData memory feesData_,
        bytes memory postBatchExecutedData_
    ) external returns (bytes32);

    function withdrawTo(
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        address receiver_,
        FeesData memory feesData_
    ) external;
}
