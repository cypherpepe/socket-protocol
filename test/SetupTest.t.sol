// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/common/Structs.sol";
import "../contracts/watcher/Watcher.sol";
import "../contracts/interfaces/IForwarder.sol";
import "../contracts/socket/utils/AccessRoles.sol";
import {Socket} from "../contracts/socket/Socket.sol";
import {SignatureVerifier} from "../contracts/socket/utils/SignatureVerifier.sol";
import {Hasher} from "../contracts/socket/utils/Hasher.sol";
import "../contracts/socket/TransmitManager.sol";
import "../contracts/socket/switchboard/FastSwitchboard.sol";
import "../contracts/AddressResolver.sol";
import {PayloadDeliveryPlug} from "../contracts/apps/payload-delivery/PayloadDeliveryPlug.sol";
import {ETH_ADDRESS} from "../contracts/common/Constants.sol";

contract SetupTest is Test {
    uint public c = 1;
    address owner = address(uint160(c++));

    uint256 watcherPrivateKey =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address watcherEOA = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 transmitterPrivateKey =
        0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    address transmitter = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

    uint32 arbChainSlug = 421614;
    uint32 optChainSlug = 11155420;

    uint256 public payloadIdCounter = 0;

    uint256 constant DEPLOY_GAS_LIMIT = 5_000_000;
    uint256 constant CONFIGURE_GAS_LIMIT = 1_000_000;

    struct SocketContracts {
        uint32 chainSlug;
        Socket socket;
        FastSwitchboard switchboard;
        TransmitManager transmitManager;
        PayloadDeliveryPlug payloadDeliveryPlug;
    }

    AddressResolver public addressResolver;
    Watcher public watcher;
    SocketContracts public arbConfig;
    SocketContracts public optConfig;

    function deploySocket(
        uint32 chainSlug_
    ) internal returns (SocketContracts memory) {
        Hasher hasher = new Hasher(owner);
        SignatureVerifier verifier = new SignatureVerifier(owner);
        Socket socket = new Socket(chainSlug_, address(hasher), owner, "test");
        FastSwitchboard switchboard = new FastSwitchboard(
            chainSlug_,
            socket,
            verifier,
            owner
        );
        TransmitManager transmitManager = new TransmitManager(
            chainSlug_,
            owner,
            hasher,
            verifier,
            socket
        );

        vm.startPrank(owner);
        // socket
        socket.grantRole(GOVERNANCE_ROLE, address(owner));
        socket.setTransmitManager(address(transmitManager));

        // switchboard
        switchboard.registerSwitchboard();
        switchboard.grantWatcherRole(watcherEOA);

        vm.stopPrank();
        return
            SocketContracts({
                chainSlug: chainSlug_,
                socket: socket,
                switchboard: switchboard,
                transmitManager: transmitManager,
                payloadDeliveryPlug: PayloadDeliveryPlug(address(0))
            });
    }

    function deployCloudCore() internal {
        watcher = new Watcher(watcherEOA);
        addressResolver = new AddressResolver(watcherEOA, address(watcher));
    }

    function _createSignature(
        bytes32 digest_,
        uint256 privateKey_
    ) internal pure returns (bytes memory sig) {
        bytes32 digest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", digest_)
        );
        (uint8 sigV, bytes32 sigR, bytes32 sigS) = vm.sign(privateKey_, digest);
        sig = new bytes(65);
        bytes1 v32 = bytes1(sigV);

        assembly {
            mstore(add(sig, 96), v32)
            mstore(add(sig, 32), sigR)
            mstore(add(sig, 64), sigS)
        }
    }

    function getSocketConfig(
        uint32 chainSlug_
    ) internal view returns (SocketContracts memory) {
        return chainSlug_ == arbChainSlug ? arbConfig : optConfig;
    }

    function createFeesData(
        uint256 maxFees_
    ) internal view returns (FeesData memory) {
        return
            FeesData({
                feePoolChain: arbChainSlug,
                feePoolToken: ETH_ADDRESS,
                maxFees: maxFees_
            });
    }

    function relayTx(
        uint32 chainSlug_,
        bytes32 payloadId,
        bytes32 root,
        address auctionHouse,
        PayloadDetails memory payloadDetails,
        bytes memory watcherSignature
    ) internal returns (bytes memory) {
        SocketContracts memory socketConfig = getSocketConfig(chainSlug_);
        bytes32 digest = keccak256(
            abi.encode(address(socketConfig.transmitManager), chainSlug_, root)
        );
        bytes memory transmitterSig = _createSignature(
            digest,
            transmitterPrivateKey
        );

        vm.startPrank(transmitter);

        ExecutePayloadParams memory params = ExecutePayloadParams({
            payloadId: payloadId,
            appGateway: auctionHouse,
            transmitter: transmitter,
            executionGasLimit: payloadDetails.executionGasLimit,
            payload: payloadDetails.payload,
            switchboard: address(socketConfig.switchboard),
            watcherSignature: watcherSignature,
            transmitterSignature: transmitterSig
        });

        bytes memory returnData = socketConfig.transmitManager.executePayload(
            params
        );
        vm.stopPrank();
        return returnData;
    }

    function markPayloadsExecuted(
        bytes32[] memory payloadIds,
        bytes[] memory returnDatas_
    ) internal {
        for (uint i = 0; i < payloadIds.length; i++) {
            markPayloadExecuted(payloadIds[i], returnDatas_[i]);
        }
    }

    function markPayloadExecuted(
        bytes32 payloadId,
        bytes memory returnData
    ) internal {
        PayloadExecution[] memory executions = new PayloadExecution[](1);
        executions[0] = PayloadExecution({
            payloadId: payloadId,
            returnData: returnData
        });
        vm.prank(watcherEOA);
        watcher.markPayloadsExecuted(executions);
    }

    function getPayloadId(
        uint32 chainSlug_,
        address plug_,
        uint256 counter_
    ) internal pure returns (bytes32) {
        return
            bytes32(
                (uint256(chainSlug_) << 224) |
                    (uint256(uint160(plug_)) << 64) |
                    counter_
            );
    }

    function getPayloadIds(
        uint32 chainSlug_,
        uint256 numPayloads,
        address plug_
    ) internal returns (bytes32[] memory) {
        bytes32[] memory payloadIds = new bytes32[](numPayloads);
        for (uint256 i = 0; i < numPayloads; i++) {
            payloadIds[i] = getPayloadId(
                chainSlug_,
                plug_,
                i + payloadIdCounter
            );
        }

        payloadIdCounter += numPayloads + 1;
        return payloadIds;
    }
}
