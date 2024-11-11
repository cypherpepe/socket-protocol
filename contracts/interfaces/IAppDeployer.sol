pragma solidity ^0.8.13;
interface IAppDeployer {
    function setForwarderContract(
        uint32 chainSlug_,
        address forwarderContractAddress_,
        address cloudContractAddress_
    ) external;
    function initialize(uint32 chainSlug) external;
    function deployContracts(uint32 chainSlug) external;
}
