// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../contracts/apps/super-token/app-gateway/SuperTokenDeployer.sol";
import "../contracts/apps/super-token/app-gateway/SuperTokenApp.sol";
import "./AuctionHouse.t.sol";

contract SuperTokenTest is AuctionHouseTest {
    struct AppContracts {
        SuperTokenApp superTokenApp;
        SuperTokenDeployer superTokenDeployer;
        address superToken;
        address limitHook;
    }
    AppContracts appContracts;

    function setUp() public {
        // core
        setUpAuctionHouse();

        // app specific
        deploySuperTokenApp();
    }

    function deploySuperTokenApp() internal {
        SuperTokenDeployer superTokenDeployer = new SuperTokenDeployer(
            address(addressResolver),
            owner,
            10000000000000000000000,
            10000000000000000000000,
            "SUPER TOKEN",
            "SUPER",
            18,
            owner,
            1000000000 ether,
            createFeesData(maxFees)
        );
        SuperTokenApp superTokenApp = new SuperTokenApp(
            address(addressResolver),
            createFeesData(maxFees),
            address(superTokenDeployer)
        );
        appContracts = AppContracts({
            superTokenApp: superTokenApp,
            superTokenDeployer: superTokenDeployer,
            superToken: superTokenDeployer.superToken(),
            limitHook: superTokenDeployer.limitHook()
        });
    }

    function createDeployPayloadDetailsArray(
        uint32 chainSlug_
    ) internal view returns (PayloadDetails[] memory) {
        PayloadDetails[] memory payloadDetails = new PayloadDetails[](2);
        payloadDetails[0] = createDeployPayloadDetail(
            chainSlug_,
            appContracts.superToken,
            address(appContracts.superTokenDeployer),
            appContracts.superTokenDeployer.creationCodeWithArgs(
                appContracts.superToken
            )
        );
        payloadDetails[1] = createDeployPayloadDetail(
            chainSlug_,
            appContracts.limitHook,
            address(appContracts.superTokenDeployer),
            appContracts.superTokenDeployer.creationCodeWithArgs(
                appContracts.limitHook
            )
        );

        SocketContracts memory socketConfig = getSocketConfig(chainSlug_);
        for (uint i = 0; i < payloadDetails.length; i++) {
            payloadDetails[i].target = address(
                socketConfig.payloadDeliveryPlug
            );
            payloadDetails[i].payload = abi.encode(
                DEPLOY,
                payloadDetails[i].payload
            );
        }
        return payloadDetails;
    }

    function createConfigurePayloadDetailsArray(
        uint32 chainSlug_
    ) internal view returns (PayloadDetails[] memory) {
        address deployedToken = IForwarder(
            appContracts.superTokenDeployer.forwarderAddresses(
                address(appContracts.superToken),
                chainSlug_
            )
        ).getOnChainAddress();

        address deployedLimitHook = IForwarder(
            appContracts.superTokenDeployer.forwarderAddresses(
                address(appContracts.limitHook),
                chainSlug_
            )
        ).getOnChainAddress();

        PayloadDetails[] memory payloadDetails = new PayloadDetails[](1);
        payloadDetails[0] = createExecutePayloadDetail(
            chainSlug_,
            deployedToken,
            abi.encodeWithSignature("setLimitHook(address)", deployedLimitHook)
        );

        SocketContracts memory socketConfig = getSocketConfig(chainSlug_);
        for (uint i = 0; i < payloadDetails.length; i++) {
            payloadDetails[i].target = address(
                socketConfig.payloadDeliveryPlug
            );
        }

        return payloadDetails;
    }

    function createBridgePayloadDetailsArray(
        uint32 srcChainSlug_,
        uint32 dstChainSlug_,
        SuperTokenApp.UserOrder memory userOrder
    ) internal view returns (PayloadDetails[] memory) {
        PayloadDetails[] memory payloadDetails = new PayloadDetails[](2);

        address deployedSrcToken = IForwarder(userOrder.srcToken)
            .getOnChainAddress();
        address deployedDstToken = IForwarder(userOrder.dstToken)
            .getOnChainAddress();
        payloadDetails[0] = createExecutePayloadDetail(
            srcChainSlug_,
            deployedSrcToken,
            abi.encodeWithSignature(
                "burn(address,uint256)",
                userOrder.user,
                userOrder.srcAmount
            )
        );

        payloadDetails[1] = createExecutePayloadDetail(
            dstChainSlug_,
            deployedDstToken,
            abi.encodeWithSignature(
                "mint(address,uint256)",
                userOrder.user,
                userOrder.srcAmount
            )
        );
        payloadDetails[0].target = address(
            getSocketConfig(srcChainSlug_).payloadDeliveryPlug
        );
        payloadDetails[1].target = address(
            getSocketConfig(dstChainSlug_).payloadDeliveryPlug
        );

        return payloadDetails;
    }

    function testContractDeployment() public {
        bytes32[] memory payloadIds = getPayloadIds(
            arbChainSlug,
            2,
            getPayloadDeliveryPlug(arbChainSlug)
        );

        PayloadDetails[]
            memory payloadDetails = createDeployPayloadDetailsArray(
                arbChainSlug
            );

        _deploy(
            payloadIds,
            arbChainSlug,
            maxFees,
            appContracts.superTokenDeployer,
            payloadDetails
        );
    }

    function testConfigure() public {
        payloadIdCounter = 0;
        bytes32[] memory payloadIds = getPayloadIds(
            arbChainSlug,
            2,
            getPayloadDeliveryPlug(arbChainSlug)
        );
        PayloadDetails[]
            memory payloadDetails = createDeployPayloadDetailsArray(
                arbChainSlug
            );
        _deploy(
            payloadIds,
            arbChainSlug,
            maxFees,
            appContracts.superTokenDeployer,
            payloadDetails
        );

        payloadIds = getPayloadIds(
            arbChainSlug,
            1,
            getPayloadDeliveryPlug(arbChainSlug)
        );
        payloadDetails = createConfigurePayloadDetailsArray(arbChainSlug);
        _configure(payloadIds, arbChainSlug, maxFees, payloadDetails);
    }

    function beforeBridge() internal {
        payloadIdCounter = 0;
        bytes32[] memory payloadIds = getPayloadIds(
            optChainSlug,
            2,
            getPayloadDeliveryPlug(optChainSlug)
        );
        PayloadDetails[]
            memory payloadDetails = createDeployPayloadDetailsArray(
                optChainSlug
            );
        _deploy(
            payloadIds,
            optChainSlug,
            maxFees,
            appContracts.superTokenDeployer,
            payloadDetails
        );

        payloadIds = getPayloadIds(
            optChainSlug,
            1,
            getPayloadDeliveryPlug(optChainSlug)
        );
        payloadDetails = createConfigurePayloadDetailsArray(optChainSlug);
        _configure(payloadIds, optChainSlug, maxFees, payloadDetails);

        payloadIds = getPayloadIds(
            arbChainSlug,
            2,
            getPayloadDeliveryPlug(arbChainSlug)
        );

        payloadDetails = createDeployPayloadDetailsArray(arbChainSlug);
        _deploy(
            payloadIds,
            arbChainSlug,
            maxFees,
            appContracts.superTokenDeployer,
            payloadDetails
        );

        payloadIds = getPayloadIds(
            arbChainSlug,
            1,
            getPayloadDeliveryPlug(arbChainSlug)
        );
        payloadDetails = createConfigurePayloadDetailsArray(arbChainSlug);
        _configure(payloadIds, arbChainSlug, maxFees, payloadDetails);
    }

    function testBridge() public {
        beforeBridge();

        SuperTokenApp.UserOrder memory userOrder = SuperTokenApp.UserOrder({
            srcToken: appContracts.superTokenDeployer.forwarderAddresses(
                address(appContracts.superToken),
                arbChainSlug
            ),
            dstToken: appContracts.superTokenDeployer.forwarderAddresses(
                address(appContracts.superToken),
                optChainSlug
            ),
            user: owner, // 2 account anvil
            srcAmount: 0.01 ether, // .01 ETH in wei
            deadline: 1672531199 // Unix timestamp for a future date
        });

        uint32 srcChainSlug = IForwarder(userOrder.srcToken).getChainSlug();
        uint32 dstChainSlug = IForwarder(userOrder.dstToken).getChainSlug();

        // bytes32[] memory payloadIds = getPayloadIds(
        //     arbChainSlug,
        //     2,
        //     getPayloadDeliveryPlug(arbChainSlug)
        // );

        bytes32[] memory payloadIds = new bytes32[](2);
        payloadIds[0] = getPayloadId(
            srcChainSlug,
            address(getSocketConfig(srcChainSlug).payloadDeliveryPlug),
            payloadIdCounter++
        );
        payloadIds[1] = getPayloadId(
            dstChainSlug,
            address(getSocketConfig(dstChainSlug).payloadDeliveryPlug),
            payloadIdCounter++
        );
        ++payloadIdCounter;

        PayloadDetails[]
            memory payloadDetails = createBridgePayloadDetailsArray(
                srcChainSlug,
                dstChainSlug,
                userOrder
            );
        FeesData memory feesData = createFeesData(maxFees);
        bytes32 expectedPayloadBatchHash = keccak256(
            abi.encode(payloadDetails, feesData, 0, payloadBatchCounter++)
        );

        bytes memory encodedOrder = abi.encode(userOrder);
        appContracts.superTokenApp.bridge(encodedOrder);
        bytes32 bridgePayloadBatchHash = expectedPayloadBatchHash;
        placeBid(bridgePayloadBatchHash);
        endAuction(bridgePayloadBatchHash);
        finalizeAndExecute(
            bridgePayloadBatchHash,
            payloadIds[0],
            payloadDetails[0]
        );
        finalizeAndExecute(
            bridgePayloadBatchHash,
            payloadIds[1],
            payloadDetails[1]
        );
    }
}
