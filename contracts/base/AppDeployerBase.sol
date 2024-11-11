// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import {DeployParams, FeesData} from "../common/Structs.sol";
import {AppGatewayBase} from "./AppGatewayBase.sol";
import {IForwarder} from "../interfaces/IForwarder.sol";
import {IAppDeployer} from "../interfaces/IAppDeployer.sol";

abstract contract AppDeployerBase is AppGatewayBase, IAppDeployer {
    mapping(address => mapping(uint32 => address)) public forwarderAddresses;
    mapping(address => bytes) public creationCodeWithArgs;

    modifier queueAndDeploy(uint32 chainSlug) {
        auctionHouse().clearDeployQueue();
        _;
        auctionHouse().deployBatch(chainSlug, feesData, abi.encode(chainSlug));
    }

    constructor(
        address _addressResolver,
        FeesData memory feesData_
    ) AppGatewayBase(_addressResolver, feesData_) {}

    // in deployer base
    function _deploy(address contractAddr) internal {
        auctionHouse().queueDeploy(
            DeployParams({
                bytecode: creationCodeWithArgs[contractAddr],
                contractAddr: contractAddr
            })
        );
    }

    function setForwarderContract(
        uint32 chainSlug,
        address forwarderContractAddr,
        address cloudContractAddr
    ) external onlyPayloadDelivery {
        forwarderAddresses[cloudContractAddr][
            chainSlug
        ] = forwarderContractAddr;
    }

    function getContractAddresses(
        address cloudContractAddr,
        uint32 chainSlug
    ) internal view returns (address forwarderContractAddr) {
        forwarderContractAddr = IForwarder(
            forwarderAddresses[cloudContractAddr][chainSlug]
        ).getOnChainAddress();
    }

    function allPayloadsExecuted(
        bytes32,
        bytes calldata postBatchExecutedData_
    ) external override {
        uint32 chainSlug = abi.decode(postBatchExecutedData_, (uint32));
        initialize(chainSlug);
    }

    function initialize(uint32 chainSlug) public virtual {}
}
