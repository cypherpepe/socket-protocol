// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import {ETH_ADDRESS, DEPLOY_GAS_LIMIT} from "../../../common/Constants.sol";
import {IAppDeployer} from "../../../interfaces/IAppDeployer.sol";
import {DeployParams, FeesData, PayloadDetails, NextFunctionInfo} from "../../../common/Structs.sol";
import {BatchExecuteModule} from "./BatchExecuteModule.sol";

abstract contract BatchDeployerModule is BatchExecuteModule {
    DeployParams[] public contractDeployList; // list of contract ids
    mapping(bytes32 => address) public deployRequests;

    constructor(
        address _addressResolver
    ) BatchExecuteModule(_addressResolver) {}

    function queueDeploy(DeployParams calldata deployParams) external {
        contractDeployList.push(deployParams);
    }

    function clearDeployQueue() external {
        delete contractDeployList;
    }

    function deployBatch(
        uint32 chainSlug_,
        FeesData memory feesData_,
        bytes memory postBatchExecutedData_
    ) external returns (bytes32 payloadBatchHash) {
        address appDeployer = msg.sender;
        PayloadDetails[] memory payloadDetails = new PayloadDetails[](
            contractDeployList.length
        );

        for (uint8 i = 0; i < contractDeployList.length; i++) {
            DeployParams memory deployParams = contractDeployList[i];
            bytes memory bytecode = deployParams.bytecode;

            bytes32 salt = keccak256(abi.encode(appDeployer, chainSlug_));
            bytes memory payload = abi.encode(bytecode, salt);
            bytes memory data = abi.encode(
                chainSlug_,
                deployParams.contractAddr
            );
            payloadDetails[i] = _getDeployPayloadDetails(
                chainSlug_,
                payload,
                bytes4(0),
                data
            );
        }

        payloadBatchHash = deliverPayload(
            payloadDetails,
            feesData_,
            0, // auctionDelay
            true,
            postBatchExecutedData_
        );
        deployRequests[payloadBatchHash] = appDeployer;
        delete contractDeployList;
    }

    function _getDeployPayloadDetails(
        uint32 chainSlug_,
        bytes memory payload_,
        bytes4 selector_,
        bytes memory data_
    ) internal pure returns (PayloadDetails memory) {
        PayloadDetails memory details = PayloadDetails({
            chainSlug: chainSlug_,
            target: address(0),
            payload: payload_,
            isContractDeployment: true,
            executionGasLimit: DEPLOY_GAS_LIMIT,
            next: NextFunctionInfo({selector: selector_, data: data_})
        });
        return details;
    }

    function setAddress(
        bytes32 payloadBatchHash_,
        bytes memory data_,
        bytes memory returnData_
    ) internal {
        (uint32 chainSlug, address deployedAddress) = abi.decode(
            data_,
            (uint32, address)
        );

        address appDeployer = deployRequests[payloadBatchHash_];

        address forwarderContractAddress = addressResolver
            .deployForwarderContract(
                appDeployer,
                abi.decode(returnData_, (address)),
                chainSlug
            );

        IAppDeployer(appDeployer).setForwarderContract(
            chainSlug,
            forwarderContractAddress,
            deployedAddress
        );
    }
}
