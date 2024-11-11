// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

interface IAppGateway {
    function callback(bytes32 payloadId_, bytes calldata returnData_) external;
    function allPayloadsExecuted(
        bytes32 payloadBatchHash_,
        bytes calldata postBatchExecutedData_
    ) external;
}
