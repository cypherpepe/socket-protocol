// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "../SuperToken.sol";
import "../LimitHook.sol";
import "../../../base/AppDeployerBase.sol";

contract SuperTokenDeployer is AppDeployerBase {
    address public superToken;
    address public limitHook;

    constructor(
        address addressResolver_,
        address owner_,
        uint256 _burnLimit,
        uint256 _mintLimit,
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address initialSupplyHolder_,
        uint256 initialSupply_,
        FeesData memory feesData_
    ) AppDeployerBase(addressResolver_, feesData_) Ownable(owner_) {
        limitHook = address(new LimitHook(_burnLimit, _mintLimit));
        superToken = address(
            new SuperToken(
                name_,
                symbol_,
                decimals_,
                initialSupplyHolder_,
                initialSupply_
            )
        );

        creationCodeWithArgs[superToken] = abi.encodePacked(
            type(SuperToken).creationCode,
            abi.encode(
                name_,
                symbol_,
                decimals_,
                initialSupplyHolder_,
                initialSupply_
            )
        );

        creationCodeWithArgs[limitHook] = abi.encodePacked(
            type(LimitHook).creationCode,
            abi.encode(_burnLimit, _mintLimit)
        );
    }

    function deployContracts(
        uint32 chainSlug
    ) external queueAndDeploy(chainSlug) {
        _deploy(superToken);
        _deploy(limitHook);
    }

    // dont need to call this directly, will be called automatically after all contracts are deployed.
    // check AppDeployerBase.allPayloadsExecuted and AppGateway.queueAndDeploy
    function initialize(uint32 chainSlug) public override queueAndExecute {
        address limitHookContract = getContractAddresses(limitHook, chainSlug);
        SuperToken(forwarderAddresses[superToken][chainSlug]).setLimitHook(
            limitHookContract
        );
    }
}
