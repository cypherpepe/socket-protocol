# Getting Started with Chubby Cheeks

This guide will help you build cross-chain applications using our framework. The framework simplifies the development of applications that need to interact across different blockchains.

## Table of Contents

- [Overview](#overview)
- [Core Components](#core-components)
- [Basic Implementation](#basic-implementation)

## Overview

The framework consists of two main contract types that developers need to implement:

1. **Deployer Contract**: Manages the deployment and configuration of your contracts across different chains
2. **App Contract**: Contains the core business logic of your cross-chain application

## Core Components

### Deployer Contract

The deployer contract handles:

- Contract deployment across multiple chains
- Configuration of cross-chain connections
- Setting up permissions and relationships between contracts

### App Contract

The app contract:

- Implements your core business logic
- Handles cross-chain message processing
- Manages state transitions across chains

## Basic Implementation

### 1. Create Your Deployer Contract

```solidity
// MyAppDeployer.sol
pragma solidity ^0.8.13;

import 'contracts/base/DeployerBase.sol';

contract MyAppDeployer is DeployerBase {
  // Define your contracts enum
  enum Contracts {
    MainContract,
    HelperContract
  }

  constructor(
    address addressResolver_,
    address payloadDelivery_,
    address owner_
  ) DeployerBase(addressResolver_, payloadDelivery_) {
    contractOwner = owner_;
  }

  // Setup function to register contract bytecodes and constructor args
  function setup(
    Contracts[] calldata contractNames_,
    bytes[] calldata bytecodes_,
    bytes[] calldata args_
  ) external {
    uint length = contractNames_.length;
    for (uint i = 0; i < length; i++) {
      args[uint8(contractNames_[i])] = args_[i];
      bytecodes[uint8(contractNames_[i])] = bytecodes_[i];
    }
  }

  // Deploy your contracts
  function deployContracts(uint32 chainSlug) external multiDeploy(chainSlug) {
    deploy(uint8(Contracts.MainContract));
    deploy(uint8(Contracts.HelperContract));
  }

  // Configure your deployed contracts
  function configure(uint32 chainSlug) external multiCall {
    (address mainProxy, address main) = getContractAddresses(
      chainSlug,
      uint8(Contracts.MainContract)
    );
    // Add your configuration logic here
  }
}
```

### 2. Create Your App Contract

```solidity
// MyApp.sol
pragma solidity ^0.8.13;

import 'contracts/base/ApplicationGatewayBase.sol';

contract MyApp is ApplicationGatewayBase {
  // Define your app-specific structs
  struct CrossChainData {
    address user;
    uint256 amount;
    uint256 deadline;
    FeesData feesData;
  }

  constructor(
    address _addressResolver,
    address _payloadDelivery
  ) ApplicationGatewayBase(_addressResolver, _payloadDelivery) {}

  // Implement your cross-chain logic
  function processCrossChainAction(bytes memory _data) external multiCall {
    CrossChainData memory data = abi.decode(_data, (CrossChainData));
    // Implement your business logic here
  }

  // Handle execution callbacks
  function markPayloadExecuted(
    bytes32 payloadId_,
    bytes calldata returnData_
  ) external override {
    // Handle execution completion
  }
}
```

### Deployment

1. Deploy your deployer contract and app contract on the VM chain.

VM Chain Details -

- rpc : https://rpc-cloud-broken-leg-7uu20euqoj.t.conduit.xyz
- chainSlug : 3605
- explorer : https://explorer-cloud-broken-leg-7uu20euqoj.t.conduit.xyz/

Addresses -

```json
{
  "WatcherVM": "0xd415B777cdb5B364D754e18228c2bDb30214E20e",
  "AddressResolver": "0xA11aB16e4D2870127Fd1a7F2AFA0AF9692637e8e",
  "PayloadDelivery": "0xa3Ffc503FD5927C02f1cC1F5C1701F7453CAeDb0"
}
```

2. prepare your contract bytecodes and constructor arguments:

```javascript

const enum Contracts {
    MainContract,
    HelperContract
}
const bytecodes = {
    MainContract: mainContractBytecode,
    HelperContract: helperContractBytecode
};

const args = {
    MainContract: encodedMainConstructorArgs,
    HelperContract: encodedHelperConstructorArgs
};
```

3.  Deploy your contracts across chains:

Once deployment is done, deploy your app on new networks easily using the deployer -

```javascript
// Setup the deployer contract

await deployer.setup(
  [Contracts.MainContract, Contracts.HelperContract],
  [bytecodes.MainContract, bytecodes.HelperContract],
  [args.MainContract, args.HelperContract],
);
// Deploy to chain A
await deployer.deployContracts(CHAIN_A_SLUG);

// Deploy to chain B
await deployer.deployContracts(CHAIN_B_SLUG);

// Configure contracts
await deployer.configure(CHAIN_A_SLUG);
await deployer.configure(CHAIN_B_SLUG);
```

4. Start using the app

## Example Usage

Here's a complete example of how to use the framework for deploying a cross-chain native supertoken:

Super Token Deployer :

```solidity
// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import '../../libraries/LibString.sol';
import './DeployerBase.sol';
import { PayloadBatch, FeesData, PayloadDetails, NextFunctionInfo } from '../../common/Structs.sol';
import { ETH_ADDRESS } from '../../common/Constants.sol';
import { IAuctionHouse } from '../../interfaces/IAuctionHouse.sol';
import { IConnectorPlug } from '../../interfaces/IConnectorPlug.sol';
import { ISuperToken } from '../../interfaces/ISuperToken.sol';
import { ILimitHook } from '../../interfaces/ILimitHook.sol';
import { IAddressAbstractor } from '../../interfaces/IAddressAbstractor.sol';

contract SuperTokenDeployer is DeployerBase {
  using LibString for uint256;
  address public contractOwner;
  enum Contracts {
    SuperToken,
    ConnectorPlug,
    LimitHook // Added LimitHook to the enum
  }

  constructor(
    address addressResolver_,
    address payloadDelivery_,
    address owner_
  ) DeployerBase(addressResolver_, payloadDelivery_) {
    contractOwner = owner_;
  }

  function setup(
    Contracts[] calldata contractNames_,
    bytes[] calldata bytecodes_,
    bytes[] calldata args_
  ) external {
    uint length = contractNames_.length;
    for (uint i = 0; i < length; i++) {
      args[uint8(contractNames_[i])] = args_[i];
      bytecodes[uint8(contractNames_[i])] = bytecodes_[i];
    }
  }

  function deployContracts(uint32 chainSlug) external multiDeploy(chainSlug) {
    deploy(uint8(Contracts.SuperToken));
    deploy(uint8(Contracts.ConnectorPlug));
    deploy(uint8(Contracts.LimitHook));
  }

  function configure(uint32 chainSlug) external multiCall {
    (address tokenProxy, address superToken) = getContractAddresses(
      chainSlug,
      uint8(Contracts.SuperToken)
    );
    (address connectorProxy, address connector) = getContractAddresses(
      chainSlug,
      uint8(Contracts.ConnectorPlug)
    );
    (, address limitHook) = getContractAddresses(
      chainSlug,
      uint8(Contracts.LimitHook)
    );

    address payloadDeliveryPlug = addressResolver.appGatewayPlugs(
      addressResolver.payloadDelivery(),
      chainSlug
    );

    ISuperToken(tokenProxy).setController(payloadDeliveryPlug);
    IConnectorPlug(connectorProxy).initialize(
      payloadDeliveryPlug,
      superToken,
      limitHook
    );
  }
}
```

Super Token App :

```solidity
// TokenBridgeApp.sol
// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import '../../base/ApplicationGatewayBase.sol';
import { PayloadBatch, FeesData, PayloadDetails, NextFunctionInfo } from '../../common/Structs.sol';
import { ISuperToken } from '../../interfaces/ISuperToken.sol';

contract SuperTokenApp is ApplicationGatewayBase {
  struct UserOrder {
    address srcToken;
    address dstToken;
    address user;
    uint256 srcAmount;
    uint256 deadline;
    FeesData feesData;
    bytes signature;
  }

  constructor(
    address _addressResolver,
    address _payloadDelivery
  ) ApplicationGatewayBase(_addressResolver, _payloadDelivery) {}

  function bridge(bytes memory _order) external multiCall {
    UserOrder memory order = abi.decode(_order, (UserOrder));

    ISuperToken(order.srcToken).burn(
      order.user,
      order.srcAmount,
      order.signature
    );
    ISuperToken(order.dstToken).mint(order.user, order.srcAmount);
  }

  function markPayloadExecuted(
    bytes32 payloadId_,
    bytes calldata returnData_
  ) external override {}
}
```

### Proxy contracts

For any on chain contract deployment, we have a proxy contract created on the vm chain.
any calls to a contract on chain can be sent to the corresponding proxy contract, which will route the call properly to the on chain contract via payload delivery.

To get your proxy contract address on VM, you can use the following mapping on your app deployer contract -

```js
    // chainSlug => ContractId (enum counter, 0 for MainContract, 1 for HelperContract, and so on) => proxy contract address
    mapping(uint32 => mapping(uint8 => address)) public proxyContracts;
```

for any function to be called on MainContract, u can use -

```js
MainContract(proxyContractAddress).crossChainFunction(...args);
```
