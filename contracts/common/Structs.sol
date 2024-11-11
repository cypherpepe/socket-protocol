// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

struct FeesData {
    uint32 feePoolChain;
    address feePoolToken;
    uint256 maxFees;
}

struct NextFunctionInfo {
    bytes4 selector;
    bytes data;
}

struct PayloadDetails {
    uint32 chainSlug;
    address target;
    bytes payload;
    bool isContractDeployment;
    uint256 executionGasLimit;
    NextFunctionInfo next;
}

struct DeployParams {
    address contractAddr;
    bytes bytecode;
}

struct CallParams {
    uint32 chainSlug;
    address target;
    bytes payload;
}

struct Bid {
    uint256 fee;
    address transmitter;
}

struct PayloadBatch {
    address appGateway;
    FeesData feesData;
    uint256 currentPayloadIndex;
    uint256 auctionEndDelayMS;
    bool sequentialProcessing;
    bytes postBatchExecutedData;
}

struct FinalizeParams {
    PayloadDetails payloadDetails;
    address transmitter;
}

struct FinalizeRequest {
    address appGateway;
    address transmitter;
    uint256 executionGasLimit;
    bytes payload;
    address switchboard;
    bytes32 root;
}

struct PayloadRootParams {
    bytes32 payloadId;
    address appGateway;
    address transmitter;
    uint256 executionGasLimit;
    bytes payload;
}

struct PlugConfig {
    address appGateway;
    address switchboard;
}

struct AppGatewayConfig {
    address plug;
    uint32 chainSlug;
    address appGateway;
    address switchboard;
}

struct PayloadExecution {
    bytes32 payloadId;
    bytes returnData;
}

struct ExecutePayloadParams {
    bytes32 payloadId;
    address appGateway;
    address transmitter;
    uint256 executionGasLimit;
    bytes payload;
    address switchboard;
    bytes watcherSignature;
    bytes transmitterSignature;
}
