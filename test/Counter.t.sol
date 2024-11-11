// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CounterGateway} from "../contracts/apps/counter/app-gateway/CounterGateway.sol";
import {CounterDeployer} from "../contracts/apps/counter/app-gateway/CounterDeployer.sol";
import {CounterPlug} from "../contracts/apps/counter/CounterPlug.sol";
import "./AuctionHouse.t.sol";

contract CounterTest is AuctionHouseTest {
    struct AppContracts {
        CounterDeployer deployer;
        CounterGateway gateway;
        address counter;
    }
    AppContracts appContracts;
    AppContracts appContracts2;

    function setUp() public {
        // core
        setUpAuctionHouse();

        // app specific
        CounterDeployer deployer = new CounterDeployer(
            address(addressResolver),
            createFeesData(maxFees)
        );

        CounterGateway gateway = new CounterGateway(
            address(addressResolver),
            address(deployer),
            createFeesData(maxFees)
        );

        CounterDeployer deployer2 = new CounterDeployer(
            address(addressResolver),
            createFeesData(maxFees)
        );

        CounterGateway gateway2 = new CounterGateway(
            address(addressResolver),
            address(deployer2),
            createFeesData(maxFees)
        );

        appContracts = AppContracts({
            deployer: deployer,
            gateway: gateway,
            counter: deployer.counterPlug()
        });
        appContracts2 = AppContracts({
            deployer: deployer2,
            gateway: gateway2,
            counter: deployer2.counterPlug()
        });
    }

    function createDeployPayloadDetailsArray(
        uint32 chainSlug_,
        AppContracts memory appContracts_
    ) internal view returns (PayloadDetails[] memory) {
        PayloadDetails[] memory payloadDetails = new PayloadDetails[](1);
        payloadDetails[0] = createDeployPayloadDetail(
            chainSlug_,
            appContracts_.counter,
            address(appContracts_.deployer),
            appContracts_.deployer.creationCodeWithArgs(appContracts_.counter)
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
        uint32 chainSlug_,
        AppContracts memory appContracts_
    ) internal view returns (PayloadDetails[] memory) {
        address deployedCounter = IForwarder(
            appContracts_.deployer.forwarderAddresses(
                appContracts_.counter,
                chainSlug_
            )
        ).getOnChainAddress();

        PayloadDetails[] memory payloadDetails = new PayloadDetails[](1);
        SocketContracts memory socketConfig = getSocketConfig(chainSlug_);
        payloadDetails[0] = createExecutePayloadDetail(
            chainSlug_,
            deployedCounter,
            abi.encodeWithSignature(
                "setSocket(address)",
                socketConfig.payloadDeliveryPlug
            )
        );

        for (uint i = 0; i < payloadDetails.length; i++) {
            payloadDetails[i].target = address(
                socketConfig.payloadDeliveryPlug
            );
        }

        return payloadDetails;
    }

    function createIncrementPayloadDetailsArray(
        uint32 chainSlug_,
        AppContracts memory appContracts_
    ) internal view returns (PayloadDetails[] memory) {
        PayloadDetails[] memory payloadDetails = new PayloadDetails[](1);
        address counterInstance = appContracts_.deployer.getContractAddresses(
            appContracts_.counter,
            chainSlug_
        );

        payloadDetails[0] = createExecutePayloadDetail(
            chainSlug_,
            counterInstance,
            abi.encodeWithSignature("increase()")
        );

        payloadDetails[0].target = address(
            getSocketConfig(chainSlug_).payloadDeliveryPlug
        );
        return payloadDetails;
    }

    function _deployCounter(
        uint32 chainSlug,
        AppContracts memory appContracts_
    ) internal {
        bytes32[] memory payloadIds = getPayloadIds(
            chainSlug,
            1,
            getPayloadDeliveryPlug(chainSlug)
        );

        PayloadDetails[]
            memory payloadDetails = createDeployPayloadDetailsArray(
                chainSlug,
                appContracts_
            );

        _deploy(
            payloadIds,
            chainSlug,
            maxFees,
            appContracts_.deployer,
            payloadDetails
        );
    }

    function _deployAndConfigureCounter(
        uint32 chainSlug,
        AppContracts memory appContracts_
    ) internal {
        _deployCounter(chainSlug, appContracts_);

        bytes32[] memory payloadIds = getPayloadIds(
            chainSlug,
            1,
            getPayloadDeliveryPlug(chainSlug)
        );
        PayloadDetails[]
            memory payloadDetails = createConfigurePayloadDetailsArray(
                chainSlug,
                appContracts_
            );
        _configure(payloadIds, chainSlug, maxFees, payloadDetails);
    }

    function testDeployCounter() public {
        _deployCounter(arbChainSlug, appContracts);
    }

    function testDeployCounters() public {
        _deployCounter(arbChainSlug, appContracts);
        payloadBatchCounter++;
        _deployCounter(arbChainSlug, appContracts2);
        payloadBatchCounter++;
        _deployCounter(arbChainSlug, appContracts2);
    }

    function testConfigure() public {
        _deployAndConfigureCounter(arbChainSlug, appContracts);
    }

    function testIncrement() public {
        _deployAndConfigureCounter(arbChainSlug, appContracts);
        _deployAndConfigureCounter(optChainSlug, appContracts);

        bytes32[] memory payloadIds = new bytes32[](1);
        payloadIds[0] = getPayloadId(
            arbChainSlug,
            address(getSocketConfig(arbChainSlug).payloadDeliveryPlug),
            payloadIdCounter++
        );

        address counterInstance = appContracts.deployer.forwarderAddresses(
            appContracts.counter,
            arbChainSlug
        );

        PayloadDetails[]
            memory payloadDetails = createIncrementPayloadDetailsArray(
                arbChainSlug,
                appContracts
            );
        FeesData memory feesData = createFeesData(maxFees);
        bytes32 expectedPayloadBatchHash = keccak256(
            abi.encode(payloadDetails, feesData, 0, payloadBatchCounter++)
        );

        appContracts.gateway.incrementCounter(counterInstance);
        bytes32 incrementPayloadBatchHash = expectedPayloadBatchHash;
        placeBid(incrementPayloadBatchHash);
        endAuction(incrementPayloadBatchHash);
        finalizeAndExecute(
            incrementPayloadBatchHash,
            payloadIds[0],
            payloadDetails[0]
        );
    }
}
