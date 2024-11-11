// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDeployer {
    function deployNext(
        uint32 chainSlug_,
        address address_,
        bytes memory output_
    ) external;
}
