# ZKsync Contracts

[![Logo](https://raw.githubusercontent.com/matter-labs/v2-testnet-contracts/main/logo.svg)](https://zksync.io)

This package contains ZKsync L1, L2 and System Contracts. For more details see the [source repository](https://github.com/matter-labs/era-contracts).

## Installation

### Hardhat

```bash
yarn add @matterlabs/zksync-contracts
```

### Foundry

```bash
forge install matter-labs/v2-testnet-contracts
```

Add the following to the `remappings.txt` file of your project:

```txt
@matterlabs/zksync-contracts/=lib/v2-testnet-contracts/
```

## Usage

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPaymaster} from "@matterlabs/zksync-contracts/contracts/system-contracts/interfaces/IPaymaster.sol";

contract MyPaymaster is IPaymaster {
     // IMPLEMENTATION
}
```

You can find a lot of useful examples in the [ZKsync docs](https://docs.zksync.io).

## License

ZKsync Contracts are distributed under the terms of the MIT license.

See [LICENSE-MIT](LICENSE-MIT) for details.

## Official Links

- [Website](https://zksync.io)
- [GitHub](https://github.com/matter-labs)
- [ZK Credo](https://github.com/zksync/credo)
- [X](https://x.com/zksync)
- [X for Devs](https://x.com/zksyncdevs)
- [Discord](https://join.zksync.dev)
- [Mirror](https://zksync.mirror.xyz)
