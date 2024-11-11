### 1. System Overview

The system is designed to support building chain-abstracted applications. It consists of two main layers: Core Components and the Wrapper Layer.

#### 1.1 Core Components

##### 1.1.1 Switchboard

The Switchboard contract is responsible for verifying that correct payloads are being delivered on-chain. It acts as a security layer to ensure the integrity of Chain abstracted messages.

Key features:

- Payload verification
- Integration with Socket for configuration management

##### 1.1.2 Socket

The Socket contract manages the configuration and piping of the system. It ensures that the correct switchboard is used for verification of a plug's payload.

Key responsibilities:

- Configuration management
- Routing payloads to the correct switchboard
- Managing plug connections

##### 1.1.3 FastSwitchboard and Watcher

FastSwitchboard is a specialized type of switchboard managed by the Watcher. The Watcher runs an off-chain VM where applications can deploy their contracts.

Key aspects:

- Off-chain VM for contract deployment
- Signing of valid requests for on-chain execution
- RPC exposure for external interaction

#### 1.2 Wrapper Layer

##### 1.2.1 Payload Delivery App

The Payload Delivery App sits on top of the core system and provides a higher-level abstraction for developers. It consists of an Application Gateway contract and a Plug contract.

Key features:

- Accepts a list of payloads
- Runs an auction to select the transmitter
- Manages payload delivery with minimum fees

##### 1.2.2 Application Gateway

The Application Gateway lives outside the chains and manages the application logic. It serves as the entry point for developers building chain-abstracted applications.

Responsibilities:

- Handling user requests
- Initiating Chain Abstracted operations
- Managing application-specific logic

##### 1.2.3 Plug Contract

The Plug contract resides on-chain and interacts with the core components. It serves as the on-chain representation of the application.

Key aspects:

- Receives and processes payloads
- Interacts with the Switchboard for payload verification
- Executes application-specific on-chain logic
