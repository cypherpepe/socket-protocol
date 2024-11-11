// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "solmate/utils/SafeTransferLib.sol";

import {ETH_ADDRESS} from "../../common/Constants.sol";

abstract contract FeesManager {
    mapping(address => mapping(address => uint256)) public balanceOf;
    mapping(uint256 => bool) public feesRedeemed;

    error FeesAlreadyPaid();

    constructor() {}

    function _handleDistributeFee(
        bytes memory data
    ) internal returns (bytes memory) {
        (
            address appGateway,
            address feeToken,
            uint256 fee,
            address transmitter,
            uint256 feesCounter
        ) = abi.decode(data, (address, address, uint256, address, uint256));

        if (feesRedeemed[feesCounter]) revert FeesAlreadyPaid();
        feesRedeemed[feesCounter] = true;

        require(
            balanceOf[appGateway][feeToken] >= fee,
            "PayloadDeliveryPlug: insufficient balance"
        );
        balanceOf[appGateway][feeToken] -= fee;
        _transferTokens(feeToken, fee, transmitter);
        return bytes("");
    }

    function _handleWithdraw(
        bytes memory data
    ) internal returns (bytes memory) {
        (
            address appGateway,
            address token,
            uint256 amount,
            address receiver
        ) = abi.decode(data, (address, address, uint256, address));

        require(
            balanceOf[appGateway][token] >= amount,
            "PayloadDeliveryPlug: insufficient balance"
        );
        balanceOf[appGateway][token] -= amount;
        _transferTokens(token, amount, receiver);
        return bytes("");
    }

    function deposit(
        address token,
        uint256 amount,
        address appGateway_
    ) external payable {
        if (token == ETH_ADDRESS) {
            require(msg.value == amount, "ConnectorPlug: invalid amount");
        } else {
            SafeTransferLib.safeTransferFrom(
                ERC20(token),
                msg.sender,
                address(this),
                amount
            );
        }
        balanceOf[appGateway_][token] += amount;
    }

    function _transferTokens(
        address token,
        uint256 amount,
        address receiver
    ) internal {
        if (token == ETH_ADDRESS) {
            SafeTransferLib.safeTransferETH(receiver, amount);
        } else {
            SafeTransferLib.safeTransfer(ERC20(token), receiver, amount);
        }
    }
}
