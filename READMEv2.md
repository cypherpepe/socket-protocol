# Getting Started with Socket Chain Abstraction

This guide will help you build chain-abstracted applications using our framework. The framework simplifies the development of applications that need to interact across different blockchains.

## Table of Contents

- [Overview](#overview)
- [Deploying a Counter](#deploying-a-counter)
- [What We Just Deployed](#what-we-just-deployed)

---

## Overview

We will explore a chain-abstracted version of the `Counter.sol` contract, inspired by the default Foundry example. The purpose of this example is to demonstrate how to implement counter logic in a way that abstracts away the details of the specific blockchain where the contract is deployed.

The goal is to provide a simple and intuitive interface for increasing a counter, ensuring that the underlying logic works seamlessly across different chains without requiring the developer to manage chain-specific details or configurations.

---

## Deploying a Counter

Let's start by deploying a chain-abstracted Counter Deployer Contract by following these steps:

1. **Setup Environment Variables**
   - Copy the `.env.sample` file and set your `$PRIVATE_KEY`. Ensure it begins with `0x`.
     ```bash
     cp .env.sample .env
     ```

2. **Deploy Contracts**
   - Use Foundry to deploy the contracts:
     ```bash
     source .env ; forge script scripts/CounterDeploy.s.sol --broadcast --rpc-url $SOCKET_RPC --verify
     ```
   - For more details on what was deployed, see [What We Just Deployed](#what-we-just-deployed). Otherwise, continue to increment the counter on a specific chain.

---

## Incrementing the Counter on a Specific Chain

To increment a counter on a specific chain, use `cast` as follows:

```bash
cast send <CONTRACT_ADDRESS> "incrementCounter(address)" <INSTANCE_ADDRESS> --private-key <PRIVATE_KEY> --rpc-url <SOCKET_RPC>
```

- Replace `<CONTRACT_ADDRESS>` with the address of the deployed `CounterGateway` contract.
- Replace `<INSTANCE_ADDRESS>` with the Forwarder address of the instance to increment.
- Ensure `$PRIVATE_KEY` and `$SOCKET_RPC` are correctly set in your `.env` file.

Each chain that has a contract deployed maintains a Forwarder Address that allows for seamless chain-abstracted functionality. Learn more about the architecture details [here](#architecture-details)

---

## API Description

This API provides essential debugging endpoints to help you troubleshoot and monitor your payload processing pipeline. You can track individual payloads, inspect batch operations, verify gateway interactions, and retrieve forwarder addresses. These endpoints are designed to give you visibility into transaction status, execution details, and system configurations when you need to understand what's happening under the hood.

Base URL: https://72e5x0myo8.execute-api.us-east-1.amazonaws.com/dev/

| **Endpoint** | **Method** | **Description** | **Parameters** | **Returns** |
|----------|---------|-------------|------------|---------|
| `/getForwarderAddress` | GET | Returns forwarder address for given chain and contract parameters | - `chainSlug` (string): Chain identifier - `contractName` (string): Name of the contract - `appDeployerAddress` (string): Address of the app deployer | Forwarder address for the specified parameters |
| `/payloadDetails` | GET | Returns details for a specific payload | `payloadId` (string): The ID of the payload to fetch details for | Object containing payload details including status, transaction hashes, and execution data |
| `/payloadBatchDetails` | GET | Returns details for a specific payload batch | `payloadBatchHash` (string): Hash of the payload batch to fetch details for | Object containing batch details including contained payloads, fees, and auction status |
| `/payloadBatchHashesByAppGateway` | GET | Returns payload batch hashes associated with an app gateway address | `appGateway` (string): Address of the app gateway to fetch batches for | Array of payload batch hashes |
| `/payloadBatchesByVMTxHash` | GET | Returns payload batches associated with a VM transaction hash | `vmTxHash` (string): Transaction hash to fetch batches for | Array of payload batch details |

---

## What We Just Deployed

By running the deployment script, we deployed three key contracts:

1. **Deployer Contract**
   - Handles contract deployment across multiple chains.
   - Configures chain-abstracted connections.
   - Sets up permissions and manages relationships between contracts.

2. **Composer Contract**
   - Implements the core business logic.
   - Handles cross-chain message processing.
   - Manages state transitions across different chains.

3. **Logic Contract**
   - Provides chain-specific functionality.

### Architecture Details

- **Deployer and Composer Contracts**: These live on an *offchain* Watcher VM. The Watcher VM monitors cross-chain events and triggers *onchain* actions on the contracts deployed on respective chains.
- **Logic Contract**: This is the *onchain* component responsible for chain-specific logic and integration.
![architecure diagram](images/architecture.png)

