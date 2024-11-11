// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./WatcherConfig.sol";
import "../interfaces/IAppGateway.sol";
import "../interfaces/IWatcher.sol";
import {Bid, PayloadRootParams, PayloadExecution, FinalizeRequest, FinalizeParams} from "../common/Structs.sol";

contract Watcher is WatcherConfig {
    uint256 public queryCounter;
    uint256 public payloadCounter;

    mapping(uint256 => bytes) public queryResponses;
    mapping(bytes32 => uint256) public queryPayloads;
    mapping(bytes32 => FinalizeRequest) public finalizeRequests;

    mapping(bytes32 => bytes) public watcherSignatures;
    error InvalidGateway();

    event QueryRequested(
        uint256 indexed queryCounter,
        uint32 chainSlug,
        address targetAddress,
        bytes payload
    );

    event FinalizeRequested(
        bytes32 indexed payloadId,
        FinalizeRequest finalizeRequest
    );

    event Finalized(
        bytes32 indexed payloadId,
        FinalizeRequest finalizeRequest,
        bytes watcherSignature
    );

    event PayloadExecuted(bytes32 indexed payloadId);

    event TimeoutRequested(address target, bytes payload, uint256 timeoutMS);
    event TimeoutResolved(address target, bytes payload, uint256 timeoutMS);

    constructor(address _owner) Ownable(_owner) {}

    // ================== Query functions ==================
    function query(
        uint32 chainSlug,
        address targetAddress,
        bytes memory payload
    ) public returns (uint256) {
        emit QueryRequested(++queryCounter, chainSlug, targetAddress, payload);
        return queryCounter;
    }

    function setQueryResponse(
        uint256 queryCounter_,
        bytes memory response
    ) external onlyOwner {
        queryResponses[queryCounter_] = response;
    }

    // ================== Timeout functions ==================

    function setTimeout(bytes calldata payload_, uint256 timeoutMS_) external {
        // Start of Selection
        emit TimeoutRequested(msg.sender, payload_, timeoutMS_);
    }

    function resolveTimeout(
        address target_,
        bytes calldata payload_,
        uint256 timeoutMS
    ) external onlyOwner {
        (bool success, ) = address(target_).call(payload_);
        require(success, "Call failed");
        emit TimeoutResolved(target_, payload_, timeoutMS);
    }

    // ================== Finalize functions ==================

    // todo: remove batch hash from params_
    function finalize(
        FinalizeParams memory params_
    ) external returns (bytes32 payloadId, bytes32 root) {
        address appGateway = msg.sender;
        _verifyConnections(
            params_.payloadDetails.chainSlug,
            params_.payloadDetails.target,
            appGateway
        );
        payloadId = encodePayloadId(
            params_.payloadDetails.chainSlug,
            params_.payloadDetails.target
        );
        PayloadRootParams memory rootParams_ = PayloadRootParams(
            payloadId,
            appGateway,
            params_.transmitter,
            params_.payloadDetails.executionGasLimit,
            params_.payloadDetails.payload
        );
        root = getRoot(rootParams_);
        (, address switchboard) = getPlugConfigs(
            params_.payloadDetails.chainSlug,
            params_.payloadDetails.target
        );
        FinalizeRequest memory finalizeRequest = FinalizeRequest(
            appGateway,
            params_.transmitter,
            params_.payloadDetails.executionGasLimit,
            params_.payloadDetails.payload,
            switchboard,
            root
        );
        finalizeRequests[payloadId] = finalizeRequest;
        emit FinalizeRequested(payloadId, finalizeRequest);
    }

    function getRoot(
        PayloadRootParams memory params_
    ) public pure returns (bytes32 root) {
        root = keccak256(
            abi.encode(
                params_.payloadId,
                params_.appGateway,
                params_.transmitter,
                params_.executionGasLimit,
                params_.payload
            )
        );
    }

    function _verifyConnections(
        uint32 chainSlug_,
        address target_,
        address appGateway_
    ) internal view {
        (address appGateway, ) = getPlugConfigs(chainSlug_, target_);
        require(appGateway == appGateway_, "Invalid connection");
    }

    function finalized(
        bytes32 payloadId_,
        bytes calldata signature_
    ) external onlyOwner {
        watcherSignatures[payloadId_] = signature_;
        emit Finalized(payloadId_, finalizeRequests[payloadId_], signature_);
    }

    // ================== Payload delivery functions ==================

    function markPayloadsExecuted(
        PayloadExecution[] calldata executions
    ) external onlyOwner {
        for (uint256 i = 0; i < executions.length; i++) {
            IAppGateway appGateway = IAppGateway(
                finalizeRequests[executions[i].payloadId].appGateway
            );

            appGateway.callback(
                executions[i].payloadId,
                executions[i].returnData
            );
            emit PayloadExecuted(executions[i].payloadId);
        }
    }

    function encodePayloadId(
        uint32 chainSlug_,
        address plug_
    ) internal returns (bytes32) {
        return
            bytes32(
                (uint256(chainSlug_) << 224) |
                    (uint256(uint160(plug_)) << 64) |
                    payloadCounter++
            );
    }
}
