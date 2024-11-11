// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./interfaces/IAppGateway.sol";
import "./interfaces/IAddressResolver.sol";
import {Forwarder} from "./Forwarder.sol";
import {Ownable} from "./utils/Ownable.sol";

contract AddressResolver is Ownable {
    // Other core addresses
    address public watcher;
    address public auctionHouse;

    bytes public forwarderBytecode = type(Forwarder).creationCode;

    // contracts to gateway map
    mapping(address => address) public contractsToGateways;
    // gateway to contract map
    mapping(address => address) public gatewaysToContracts;
    event PlugAdded(address appGateway, uint32 chainSlug, address plug);
    event ForwarderDeployed(address newForwarder, bytes32 salt);

    error AppGatewayContractAlreadySetByDifferentSender(
        address contractAddress_
    );

    constructor(address _owner, address _watcher) Ownable(_owner) {
        watcher = _watcher;
    }

    function setForwarderBytecode(bytes memory _forwarderBytecode) external {
        forwarderBytecode = _forwarderBytecode;
    }

    // Function to update core addresses
    function setAuctionHouse(address _auctionHouse) external onlyOwner {
        auctionHouse = _auctionHouse;
    }

    function setWatcher(address _watcher) external onlyOwner {
        watcher = _watcher;
    }

    function deployForwarderContract(
        address appDeployer_,
        address chainContractAddress_,
        uint32 chainSlug_
    ) public returns (address) {
        bytes memory constructorArgs = abi.encode(
            chainSlug_,
            chainContractAddress_,
            address(this)
        );

        bytes memory combinedBytecode = abi.encodePacked(
            forwarderBytecode,
            constructorArgs
        );

        bytes32 salt = keccak256(constructorArgs);
        address newForwarder;

        assembly {
            newForwarder := create2(
                callvalue(),
                add(combinedBytecode, 0x20),
                mload(combinedBytecode),
                salt
            )
            if iszero(extcodesize(newForwarder)) {
                revert(0, 0)
            }
        }
        emit ForwarderDeployed(newForwarder, salt);

        address gateway = contractsToGateways[appDeployer_];
        gatewaysToContracts[gateway] = newForwarder;
        contractsToGateways[newForwarder] = gateway;
        return newForwarder;
    }

    function setContractsToGateways(address contractAddress_) external {
        if (
            contractsToGateways[contractAddress_] != address(0) &&
            contractsToGateways[contractAddress_] != msg.sender
        ) {
            revert AppGatewayContractAlreadySetByDifferentSender(
                contractAddress_
            );
        }
        contractsToGateways[contractAddress_] = msg.sender;
    }

    function getAddress(
        address chainContractAddress_,
        uint32 chainSlug_
    ) public view returns (address) {
        bytes memory constructorArgs = abi.encode(
            chainContractAddress_,
            chainSlug_
        );
        bytes memory combinedBytecode = abi.encodePacked(
            forwarderBytecode,
            constructorArgs
        );
        bytes32 salt = keccak256(constructorArgs);

        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(abi.encodePacked(combinedBytecode, constructorArgs))
            )
        );

        return address(uint160(uint256(hash)));
    }
}
