// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "../common/Structs.sol";

interface IWatcher {
    function query(
        uint32 chainSlug,
        address targetAddress,
        bytes memory payload
    ) external returns (uint256);

    function setQueryResponse(
        uint256 queryCounter_,
        bytes memory response
    ) external;

    function setTimeout(bytes calldata payload_, uint256 timeoutMS_) external;

    function resolveTimeout(
        address target_,
        bytes calldata payload_,
        uint256 timeoutMS
    ) external;

    function finalize(
        FinalizeParams memory params_
    ) external returns (bytes32 payloadId, bytes32 root);

    function getRoot(
        PayloadRootParams memory params_
    ) external pure returns (bytes32 root);

    function finalized(bytes32 payloadId_, bytes calldata signature_) external;

    function markPayloadsExecuted(
        PayloadExecution[] calldata executions
    ) external;

    function appGatewayPlugs(
        address appGateway_,
        uint32 chainSlug_
    ) external view returns (address);
}
