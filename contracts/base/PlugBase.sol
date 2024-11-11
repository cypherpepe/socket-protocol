// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ISocket} from "../interfaces/ISocket.sol";
import {IPlug} from "../interfaces/IPlug.sol";
import {NotSocket} from "../common/Errors.sol";

abstract contract PlugBase is IPlug {
    ISocket public socket__;
    uint32 public chainSlug;

    event ConnectorPlugDisconnected();

    constructor(address socket_, uint32 chainSlug_) {
        socket__ = ISocket(socket_);
        chainSlug = chainSlug_;
    }

    modifier onlySocket() {
        if (msg.sender != address(socket__)) revert NotSocket();
        _;
    }

    function inbound(
        bytes calldata payload_
    ) external payable virtual returns (bytes memory) {}

    // todo: only owner
    function connect(address appGateway_, address switchboard_) external {
        socket__.connect(appGateway_, switchboard_);
    }

    function disconnect() internal {
        (, address switchboard) = socket__.getPlugConfig(address(this));
        socket__.connect(address(0), switchboard);
        emit ConnectorPlugDisconnected();
    }

    function setSocket(address socket_) internal {
        socket__ = ISocket(socket_);
    }
}
