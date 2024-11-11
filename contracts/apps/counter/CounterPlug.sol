// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../../utils/Ownable.sol";

contract CounterPlug is Ownable(msg.sender) {
    address public socket;
    uint256 public counter;

    modifier onlySocket() {
        require(msg.sender == socket, "not sokcet");
        _;
    }

    function setSocket(address _socket) external onlyOwner {
        socket = _socket;
    }

    function getSocket() external view returns (address) {
        return socket;
    }

    function increase() external onlySocket {
        counter++;
    }
}
