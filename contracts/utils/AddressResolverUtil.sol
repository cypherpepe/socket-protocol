// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "../interfaces/IAddressResolver.sol";
import "../interfaces/IAuctionHouse.sol";
import "../interfaces/IWatcher.sol";

abstract contract AddressResolverUtil {
    IAddressResolver public addressResolver;

    constructor(address _addressResolver) {
        addressResolver = IAddressResolver(_addressResolver);
    }

    modifier onlyPayloadDelivery() {
        require(
            msg.sender == addressResolver.auctionHouse(),
            "Only payload delivery"
        );
        _;
    }

    modifier onlyWatcher() {
        require(
            msg.sender == address(addressResolver.watcher()),
            "Only watcher"
        );
        _;
    }

    function auctionHouse() public view returns (IAuctionHouse) {
        return IAuctionHouse(addressResolver.auctionHouse());
    }

    function watcher() public view returns (IWatcher) {
        return IWatcher(addressResolver.watcher());
    }

    function setAddressResolver(address _addressResolver) internal {
        addressResolver = IAddressResolver(_addressResolver);
    }
}
