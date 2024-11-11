// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

/**
 * @title ISocket
 * @notice An interface for a Chain Abstraction contract
 * @dev This interface provides methods for transmitting and executing messages between chains,
 * connecting a plug to a remote chain and setting up switchboards for the message transmission
 * This interface also emits events for important operations such as message transmission, execution status,
 * and plug connection
 */
interface ISocket {
    /**
     * @notice emits the status of message after inbound call
     * @param msgId msg id which is executed
     */
    event ExecutionSuccess(bytes32 msgId, bytes returnData);

    /**
     * @notice emits the config set by a plug for a remoteChainSlug
     * @param plug address of plug on current chain
     * @param appGateway address of plug on sibling chain
     * @param switchboard outbound switchboard (select from registered options)
     */
    event PlugConnected(address plug, address appGateway, address switchboard);

    /**
     * @notice executes a message
     */
    function execute(
        bytes32 payloadId_,
        address appGateway_,
        address transmitter_,
        uint256 executionGasLimit_,
        bytes memory payload_
    ) external payable returns (bytes memory);

    /**
     * @notice sets the config specific to the plug
     * @param appGateway_ address of plug present at sibling chain to call inbound
     * @param switchboard_ the address of switchboard to use for sending messages
     */
    function connect(address appGateway_, address switchboard_) external;

    /// return instance of transmit manager
    function transmitManager__() external view returns (address);

    function registerSwitchboard() external;

    /**
     * @notice returns the config for given `plugAddress_` and `siblingChainSlug_`
     * @param plugAddress_ address of plug present at current chain
     */
    function getPlugConfig(
        address plugAddress_
    ) external view returns (address appGateway, address switchboard__);
}
