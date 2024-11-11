// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;
import {AddressResolverUtil} from "../../../utils/AddressResolverUtil.sol";

import {IAuctionHouse} from "../../../interfaces/IAuctionHouse.sol";
import {CallParams, FeesData, PayloadDetails, NextFunctionInfo} from "../../../common/Structs.sol";
import {IAddressResolver} from "../../../interfaces/IAddressResolver.sol";

abstract contract BatchExecuteModule is IAuctionHouse, AddressResolverUtil {
    CallParams[] public callParamsArray;

    constructor(
        address _addressResolver
    ) AddressResolverUtil(_addressResolver) {}

    function queue(
        uint32 chainSlug_,
        address target_,
        bytes memory payload_
    ) external {
        CallParams memory newCallParams = CallParams({
            chainSlug: chainSlug_,
            target: target_,
            payload: payload_
        });
        callParamsArray.push(newCallParams);
    }

    function clearQueue() external {
        delete callParamsArray;
    }

    function _getCallPayloadDetails(
        uint32 chainSlug_,
        address target_,
        bytes memory payload_
    ) internal pure returns (PayloadDetails memory) {
        PayloadDetails memory details = PayloadDetails({
            chainSlug: chainSlug_,
            target: target_,
            payload: payload_,
            isContractDeployment: false,
            executionGasLimit: 1_000_000,
            next: NextFunctionInfo({selector: bytes4(0), data: ""})
        });
        return details;
    }

    function executeBatch(
        FeesData memory feesData_,
        uint256 auctionEndDelayMS_,
        bool sequentialProcessing_,
        bytes memory postBatchExecutedData_
    ) external returns (bytes32) {
        PayloadDetails[] memory payloadDetailsArray = new PayloadDetails[](
            callParamsArray.length
        );
        for (uint256 i = 0; i < callParamsArray.length; i++) {
            CallParams memory params = callParamsArray[i];
            PayloadDetails memory payloadDetails = _getCallPayloadDetails(
                params.chainSlug,
                params.target,
                params.payload
            );
            payloadDetailsArray[i] = payloadDetails;
        }

        delete callParamsArray;
        return
            deliverPayload(
                payloadDetailsArray,
                feesData_,
                auctionEndDelayMS_,
                sequentialProcessing_,
                postBatchExecutedData_
            );
    }

    function deliverPayload(
        PayloadDetails[] memory payloadDetails_,
        FeesData memory feesData_,
        uint256 auctionEndDelayMS_,
        bool sequentialProcessing_,
        bytes memory postBatchExecutedData_
    ) public virtual returns (bytes32) {}
}
