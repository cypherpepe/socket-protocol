// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./ERC20.sol";
import {Ownable} from "../../utils/Ownable.sol";
import "../../interfaces/ISuperToken.sol";
import {LimitHook} from "./LimitHook.sol";

/**
 * @title SuperToken
 * @notice An ERC20 contract which enables bridging a token to its sibling chains.
 * @dev This contract implements ISuperTokenOrVault to support message bridging through IMessageBridge compliant contracts.
 */
contract SuperToken is ERC20, Ownable(msg.sender), ISuperToken {
    address public override controller;
    LimitHook public limitHook;

    error NotController();

    modifier onlyController() {
        if (msg.sender != controller) revert NotController();
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address initialSupplyHolder_,
        uint256 initialSupply_
    ) ERC20(name_, symbol_, decimals_) {
        _mint(initialSupplyHolder_, initialSupply_);
        controller = msg.sender;
    }

    function burn(
        address user_,
        uint256 amount_
    ) external override onlyController {
        limitHook.beforeBurn(amount_);
        _burn(user_, amount_);
    }

    function mint(
        address receiver_,
        uint256 amount_
    ) external override onlyController {
        limitHook.beforeMint(amount_);
        _mint(receiver_, amount_);
    }

    function setController(address newController_) external onlyOwner {
        controller = newController_;
    }

    function setLimitHook(address limitHook_) external onlyOwner {
        limitHook = LimitHook(limitHook_);
    }
}
