// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

import "../interfaces/ISocket.sol";
import "../interfaces/ISignatureVerifier.sol";
import "../interfaces/IHasher.sol";

import "../interfaces/ISwitchboard.sol";
import "../utils/Ownable.sol";
import {ExecutePayloadParams} from "../common/Structs.sol";

/**
 * @title TransmitManager
 * @notice The TransmitManager contract managers transmitter which facilitates communication between chains
 * @dev This contract is responsible access control of transmitters and their fees
 * @dev This contract inherits AccessControlExtended which extends access control
 * @dev The transmission fees is collected in execution manager which can be pulled from it when needed
 */
contract TransmitManager is Ownable {
    // chain slug of the current chain
    uint32 public immutable chainSlug;
    // socket contract
    ISocket public immutable socket__;
    IHasher public hasher__;
    ISignatureVerifier public signatureVerifier__;

    error InvalidTransmitter();

    /**
     * @notice Initializes the TransmitManager contract
     * @param socket_ The address of socket contract
     * @param owner_ The owner of the contract with GOVERNANCE_ROLE
     * @param chainSlug_ The chain slug of the current chain
     */
    constructor(
        uint32 chainSlug_,
        address owner_,
        IHasher hasher_,
        ISignatureVerifier signatureVerifier_,
        ISocket socket_
    ) Ownable(owner_) {
        chainSlug = chainSlug_;
        socket__ = socket_;
        signatureVerifier__ = signatureVerifier_;
        hasher__ = hasher_;
    }

    function executePayload(
        ExecutePayloadParams calldata params
    ) external returns (bytes memory) {
        bytes32 root = hasher__.packMessage(
            params.payloadId,
            params.appGateway,
            params.transmitter,
            params.executionGasLimit,
            params.payload
        );

        address transmitter = signatureVerifier__.recoverSigner(
            keccak256(abi.encode(address(this), chainSlug, root)),
            params.transmitterSignature
        );

        if (transmitter != params.transmitter) revert InvalidTransmitter();
        ISwitchboard(params.switchboard).attest(
            params.payloadId,
            root,
            params.watcherSignature
        );
        return
            socket__.execute(
                params.payloadId,
                params.appGateway,
                params.transmitter,
                params.executionGasLimit,
                params.payload
            );
    }
}
