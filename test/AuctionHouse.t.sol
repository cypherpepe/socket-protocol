// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../contracts/apps/payload-delivery/app-gateway/AuctionHouse.sol";
import "../contracts/Forwarder.sol";
import "../contracts/interfaces/IAppDeployer.sol";

import "./SetupTest.t.sol";

contract AuctionHouseTest is SetupTest {
    uint256 public maxFees = 0.0001 ether;
    uint256 public bidAmount = maxFees / 100;

    AuctionHouse auctionHouse;
    uint256 public payloadBatchCounter;

    event PayloadSubmitted(
        bytes32 indexed payloadBatchHash,
        address indexed appGateway,
        PayloadDetails[] payloads,
        FeesData feesData,
        uint256 auctionEndDelay
    );
    event BidPlaced(bytes32 indexed payloadBatchHash, Bid bid);
    event AuctionEnded(bytes32 indexed payloadBatchHash, Bid winningBid);

    function setUpAuctionHouse() internal {
        // core
        deployCloudCore();
        auctionHouse = new AuctionHouse(address(addressResolver));

        hoax(watcherEOA);
        addressResolver.setAuctionHouse(address(auctionHouse));

        // chain core contracts
        arbConfig = deploySocket(arbChainSlug);
        arbConfig.payloadDeliveryPlug = new PayloadDeliveryPlug(
            address(arbConfig.socket),
            arbChainSlug,
            owner
        );

        optConfig = deploySocket(optChainSlug);
        optConfig.payloadDeliveryPlug = new PayloadDeliveryPlug(
            address(optConfig.socket),
            optChainSlug,
            owner
        );

        vm.startPrank(owner);
        arbConfig.payloadDeliveryPlug.connect(
            address(auctionHouse),
            address(arbConfig.switchboard)
        );
        optConfig.payloadDeliveryPlug.connect(
            address(auctionHouse),
            address(optConfig.switchboard)
        );
        vm.stopPrank();

        connectAuctionHouse();
    }

    function connectAuctionHouse() internal {
        AppGatewayConfig[] memory gateways = new AppGatewayConfig[](2);
        gateways[0] = AppGatewayConfig({
            plug: address(arbConfig.payloadDeliveryPlug),
            chainSlug: arbChainSlug,
            appGateway: address(auctionHouse),
            switchboard: address(arbConfig.switchboard)
        });
        gateways[1] = AppGatewayConfig({
            plug: address(optConfig.payloadDeliveryPlug),
            chainSlug: optChainSlug,
            appGateway: address(auctionHouse),
            switchboard: address(optConfig.switchboard)
        });

        hoax(watcherEOA);
        watcher.setAppGateways(gateways);
    }

    //// BATCH DEPLOY AND EXECUTE HELPERS ////

    function _deploy(
        bytes32[] memory payloadIds,
        uint32 chainSlug_,
        uint256 maxFees_,
        IAppDeployer appDeployer_,
        PayloadDetails[] memory payloadDetails_
    ) internal {
        FeesData memory feesData = createFeesData(maxFees_);
        bytes32 payloadBatchHash = keccak256(
            abi.encode(payloadDetails_, feesData, 0, payloadBatchCounter++)
        );

        appDeployer_.deployContracts(chainSlug_);

        placeBid(payloadBatchHash);
        endAuction(payloadBatchHash);

        for (uint i = 0; i < payloadIds.length; i++) {
            finalizeAndExecute(
                payloadBatchHash,
                payloadIds[i],
                payloadDetails_[i]
            );
        }
    }

    function _configure(
        bytes32[] memory payloadIds,
        uint32 chainSlug_,
        uint256 maxFees_,
        PayloadDetails[] memory payloadDetails_
    ) internal {
        FeesData memory feesData = createFeesData(maxFees_);
        bytes32 payloadBatchHash = keccak256(
            abi.encode(payloadDetails_, feesData, 0, payloadBatchCounter++)
        );

        placeBid(payloadBatchHash);
        endAuction(payloadBatchHash);
        for (uint i = 0; i < payloadIds.length; i++) {
            finalizeAndExecute(
                payloadBatchHash,
                payloadIds[i],
                payloadDetails_[i]
            );
        }
    }

    function createDeployPayloadDetail(
        uint32 chainSlug_,
        address vmContractAddr_,
        address appDeployer_,
        bytes memory bytecode_
    ) internal view returns (PayloadDetails memory) {
        bytes32 salt = keccak256(abi.encode(appDeployer_, chainSlug_));
        bytes memory payload = abi.encode(bytecode_, salt);
        bytes memory data = abi.encode(chainSlug_, vmContractAddr_);

        return
            createPayloadDetails(
                chainSlug_,
                address(0),
                payload,
                true,
                DEPLOY_GAS_LIMIT,
                data
            );
    }

    function getPayloadDeliveryPlug(
        uint32 chainSlug_
    ) internal view returns (address) {
        return address(getSocketConfig(chainSlug_).payloadDeliveryPlug);
    }

    function createPayloadDetails(
        uint32 chainSlug_,
        address target_,
        bytes memory payload_,
        bool isContractDeployment_,
        uint256 executionGasLimit_,
        bytes memory data_
    ) internal pure returns (PayloadDetails memory) {
        return
            PayloadDetails({
                chainSlug: chainSlug_,
                target: target_,
                payload: payload_,
                isContractDeployment: isContractDeployment_,
                executionGasLimit: executionGasLimit_,
                next: NextFunctionInfo({selector: bytes4(0), data: data_})
            });
    }

    //// AUCTION RELATED FUNCTIONS ////
    function placeBid(bytes32 payloadBatchHash) internal {
        vm.expectEmit(true, true, false, false);
        emit BidPlaced(
            payloadBatchHash,
            Bid({fee: bidAmount, transmitter: transmitter})
        );
        vm.prank(transmitter);
        auctionHouse.bid(payloadBatchHash, bidAmount);
    }

    function endAuction(bytes32 payloadBatchHash) internal {
        vm.expectEmit(true, false, false, true);
        emit AuctionEnded(
            payloadBatchHash,
            Bid({fee: bidAmount, transmitter: transmitter})
        );

        hoax(watcherEOA);
        watcher.resolveTimeout(
            address(auctionHouse),
            abi.encodeWithSelector(
                AuctionHouse.endAuction.selector,
                payloadBatchHash
            ),
            0
        );
    }

    function finalize(
        bytes32,
        bytes32 payloadId,
        PayloadDetails memory payloadDetails
    ) internal view returns (bytes memory, bytes32) {
        SocketContracts memory socketConfig = getSocketConfig(
            payloadDetails.chainSlug
        );
        PayloadRootParams memory rootParams_ = PayloadRootParams(
            payloadId,
            address(auctionHouse),
            transmitter,
            payloadDetails.executionGasLimit,
            payloadDetails.payload
        );
        bytes32 root = watcher.getRoot(rootParams_);

        bytes32 digest = keccak256(
            abi.encode(address(socketConfig.switchboard), root)
        );
        bytes memory watcherSig = _createSignature(digest, watcherPrivateKey);
        return (watcherSig, root);
    }

    function createExecutePayloadDetail(
        uint32 chainSlug_,
        address target_,
        bytes memory payload_
    ) internal pure returns (PayloadDetails memory) {
        bytes memory payload = abi.encode(
            FORWARD_CALL,
            abi.encode(target_, payload_)
        );

        return
            createPayloadDetails(
                chainSlug_,
                target_,
                payload,
                false,
                CONFIGURE_GAS_LIMIT,
                ""
            );
    }

    function finalizeAndExecute(
        bytes32 payloadBatchHash,
        bytes32 payloadId,
        PayloadDetails memory payloadDetails
    ) internal {
        (bytes memory watcherSig, bytes32 root) = finalize(
            payloadBatchHash,
            payloadId,
            payloadDetails
        );
        bytes memory returnData = relayTx(
            payloadDetails.chainSlug,
            payloadId,
            root,
            address(auctionHouse),
            payloadDetails,
            watcherSig
        );
        markPayloadExecuted(payloadId, returnData);
    }
}
