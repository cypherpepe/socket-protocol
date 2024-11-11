// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

import "../interfaces/IPlug.sol";
import "./SocketBase.sol";

/**
 * @title SocketDst
 * @dev SocketDst is an abstract contract that inherits from SocketBase and
 * provides functionality for message execution, verification.
 * It manages the mapping of message execution status
 * timestamps
 * It also includes functions for message execution and verification
 */
contract Socket is SocketBase {
    ////////////////////////////////////////////////////////
    ////////////////////// ERRORS //////////////////////////
    ////////////////////////////////////////////////////////
    /**
     * @dev Error emitted when proof is invalid
     */

    /**
     * @dev Error emitted when a message has already been executed
     */
    error MessageAlreadyExecuted();
    /**
     * @dev Error emitted when the executor is not valid
     */
    /**
     * @dev Error emitted when verification fails
     */
    error VerificationFailed();
    /**
     * @dev Error emitted when source slugs deduced from packet id and msg id don't match
     */
    error InvalidAppGateway();
    /**
     * @dev Error emitted when less gas limit is provided for execution than expected
     */
    error LowGasLimit();
    error InvalidSlug();

    ////////////////////////////////////////////////////////////
    ////////////////////// State Vars //////////////////////////
    ////////////////////////////////////////////////////////////

    /**
     * @dev keeps track of whether a message has been executed or not using message id
     */
    mapping(bytes32 => bool) public payloadExecuted;

    constructor(
        uint32 chainSlug_,
        address hasher_,
        address owner_,
        string memory version_
    ) SocketBase(chainSlug_, hasher_, owner_, version_) {}

    ////////////////////////////////////////////////////////
    ////////////////////// OPERATIONS //////////////////////////
    ////////////////////////////////////////////////////////

    /**
     * @notice Executes a message that has been delivered by transmitters and authenticated by switchboards
     */
    function execute(
        bytes32 payloadId_,
        address appGateway_,
        address transmitter_,
        uint256 executionGasLimit_,
        bytes memory payload_
    ) external payable onlyTransmitManager returns (bytes memory) {
        // make sure message is not executed already
        if (payloadExecuted[payloadId_]) revert MessageAlreadyExecuted();
        // update state to make sure no reentrancy
        payloadExecuted[payloadId_] = true;

        // extract plug address from msgID
        address localPlug = _decodePlug(payloadId_);
        uint32 localSlug = _decodeChainSlug(payloadId_);

        if (localSlug != chainSlug) revert InvalidSlug();

        // fetch required vars from plug config
        if (_plugConfigs[localPlug].appGateway != appGateway_)
            revert InvalidAppGateway();

        // create packed message
        bytes32 root = hasher__.packMessage(
            payloadId_,
            appGateway_,
            transmitter_,
            executionGasLimit_,
            payload_
        );

        // verify message was part of the packet and
        // authenticated by respective switchboard
        _verify(root, payloadId_, _plugConfigs[localPlug].switchboard__);

        // execute message
        return _execute(localPlug, payloadId_, executionGasLimit_, payload_);
    }

    ////////////////////////////////////////////////////////
    ////////////////// INTERNAL FUNCS //////////////////////
    ////////////////////////////////////////////////////////

    function _verify(
        bytes32 root_,
        bytes32 payloadId_,
        ISwitchboard switchboard__
    ) internal view {
        // NOTE: is the the first un-trusted call in the system, another one is Plug.inbound
        if (!switchboard__.allowPacket(root_, payloadId_))
            revert VerificationFailed();
    }

    /**
     * This function assumes localPlug_ will have code while executing. As the message
     * execution failure is not blocking the system, it is not necessary to check if
     * code exists in the given address.
     */
    function _execute(
        address localPlug_,
        bytes32 payloadId_,
        uint256 executionGasLimit_,
        bytes memory payload_
    ) internal returns (bytes memory) {
        if (gasleft() < executionGasLimit_) revert LowGasLimit();
        // NOTE: external un-trusted call
        bytes memory returnData = IPlug(localPlug_).inbound{
            gas: executionGasLimit_,
            value: msg.value
        }(payload_);
        emit ExecutionSuccess(payloadId_, returnData);
        return returnData;
    }

    /**
     * @dev Decodes the plug address from a given message id.
     * @param id_ The ID of the msg to decode the plug from.
     * @return plug_ The address of sibling plug decoded from the message ID.
     */
    function _decodePlug(bytes32 id_) internal pure returns (address plug_) {
        plug_ = address(uint160(uint256(id_) >> 64));
    }

    /**
     * @dev Decodes the chain ID from a given packet/message ID.
     * @param id_ The ID of the packet/msg to decode the chain slug from.
     * @return chainSlug_ The chain slug decoded from the packet/message ID.
     */
    function _decodeChainSlug(
        bytes32 id_
    ) internal pure returns (uint32 chainSlug_) {
        chainSlug_ = uint32(uint256(id_) >> 224);
    }
}
