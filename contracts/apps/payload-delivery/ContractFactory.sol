// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {DEPLOY, CONFIGURE, ETH_ADDRESS} from "../../common/Constants.sol";

abstract contract ContractFactory {
    event Deployed(address addr, bytes32 salt);

    function _handleDeploy(bytes memory data) internal returns (bytes memory) {
        address deployedAddress = deployContract(data);
        return abi.encode(deployedAddress);
    }

    function deployContract(
        bytes memory data
    ) public payable returns (address) {
        (bytes memory creationCode, bytes32 salt) = abi.decode(
            data,
            (bytes, bytes32)
        );

        address addr;
        assembly {
            addr := create2(
                callvalue(),
                add(creationCode, 0x20),
                mload(creationCode),
                salt
            )
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }

        emit Deployed(addr, salt);
        return addr;
    }

    function getAddress(
        bytes memory creationCode,
        uint256 salt
    ) public view returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(creationCode)
            )
        );

        return address(uint160(uint256(hash)));
    }
}
