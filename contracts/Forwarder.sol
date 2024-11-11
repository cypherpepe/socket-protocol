// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/IAddressResolver.sol";
import "./interfaces/IAuctionHouse.sol";

contract Forwarder {
    uint32 immutable chainSlug;
    address immutable onChainAddress;
    address immutable addressResolver;

    constructor(
        uint32 chainSlug_,
        address onChainAddress_,
        address addressResolver_
    ) {
        chainSlug = chainSlug_;
        onChainAddress = onChainAddress_;
        addressResolver = addressResolver_;
    }

    function getOnChainAddress() external view returns (address) {
        return onChainAddress;
    }

    function getChainSlug() external view returns (uint32) {
        return chainSlug;
    }

    fallback() external payable {
        // todo check if possible to remove addressResolver
        address auctionHouse = IAddressResolver(addressResolver).auctionHouse();

        if (auctionHouse == address(0)) {
            revert("Forwarder: auctionHouse not found");
        }
        IAuctionHouse(auctionHouse).queue(chainSlug, onChainAddress, msg.data);
    }

    receive() external payable {}
}
