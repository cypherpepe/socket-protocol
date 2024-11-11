### 2. Building Your Own Application

#### 2.1 Using Payload Delivery App

The Payload Delivery App provides a high-level abstraction for developers to build chain-abstracted applications. Here's how to use it:

1. Deploy an Application Gateway contract:

- Inherit from `ApplicationGatewayBase`
- Implement application-specific logic

2. Deploy Plug contracts on target chains:

- Use `PayloadDeliveryPlug` as a base
- Customize as needed for your application

3. Integrate with PayloadDelivery contract:

- Use `deliverPayload` function to submit Chain Abstracted operations
- Handle payload execution in your Plug contracts

Example workflow:

```solidity
contract MyApp is ApplicationGatewayBase {
  constructor(address watcher, address _watcherVM, address _payloadDelivery) ApplicationGatewayBase(watcher, _watcherVM, _payloadDelivery) {}

  function chainAbstractedOperation(uint32 targetChain, bytes memory data) external {
    PayloadDetails[] memory payloads = new PayloadDetails;

    payloads[0] = PayloadDetails({
      chainSlug: targetChain,
      target: getPlugAddress(targetChain),
      payload: data,
      executionGasLimit: 200000
    });

    FeesData memory feesData = // ... set up fees data
    uint256 auctionEndDelay = 5 minutes;

    payloadDelivery.deliverPayload(payloads, feesData, auctionEndDelay);
  }
}
```

#### 2.2 Direct Interaction with Core System

For more advanced use cases or custom implementations, you can interact directly with the core system:

1. Implement your own Application Gateway:

- Interact with the WatcherVM contract
- Manage payload finalization and execution

2. Create custom Plug contracts:

- Implement the `IPlug` interface
- Handle inbound payloads and execute application logic

3. Integrate with Socket and Switchboard:

- Use Socket for configuration management
- Leverage Switchboard for payload verification

Example of direct core system interaction:

```solidity
contract MyCustomApp {
  IWatcherVM public watcherVM;
  ISocket public socket;

  constructor(address watcherVM, address _socket) {
    watcherVM = IWatcherVM(watcherVM);
    socket = ISocket(socket);
  }

  function sendChainAbstractedMessage(
    uint32 targetChain,
    bytes memory message
  ) external {
    // Prepare payload
    PayloadDetails memory payload = PayloadDetails({
      chainSlug: targetChain,
      target: getMyPlugAddress(targetChain),
      payload: message,
      executionGasLimit: 200000
    });

    // Finalize payload with WatcherVM
    FinalizeParams memory params = FinalizeParams({
      payloadDetails: payload,
      transmitter: address(this)
    });

    (bytes32 payloadId, ) = watcherVM.finalize(params);
    // Handle payload execution (implement callback or polling mechanism)
  }

  function getMyPlugAddress(uint32 chainSlug) public view returns (address) {
    return watcherVM.appGatewayPlugs(address(this), chainSlug);
  }
}
```

When building directly on the core system, ensure proper security measures and thorough testing, as you'll be responsible for managing more low-level interactions.
