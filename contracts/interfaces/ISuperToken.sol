// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ISuperToken {
    function burn(address user_, uint256 amount_) external;

    function mint(address receiver_, uint256 amount_) external;

    // Public variable
    function controller() external view returns (address);

    function setController(address controller_) external;
}
