# Remote Owner

[![Code Coverage](https://github.com/generationsoftware/remote-owner/actions/workflows/coverage.yml/badge.svg)](https://github.com/generationsoftware/remote-owner/actions/workflows/coverage.yml)
![MIT license](https://img.shields.io/badge/license-MIT-blue)

The Remote Owner contract allows an account one on chain to have a "remote" account on another chain using an [ERC-5164 compatible bridge](https://eips.ethereum.org/EIPS/eip-5164). The contract uses ERC-5164 so that the bridge layer is swappable.

For example, this might be useful for a Governance system on Ethereum that wants extend itself to Optimism. Someone could deploy a RemoteOwner on Optimism and set the owner to be the Governance address and the fromChainId to be 1. The Governance system on Ethereum can then send execution messages through a ERC-5164 bridge layer to the RemoteOwner. The account would execute the transactions; effectively acting as Governance on Optimism.

Links

- [EIP-5164](https://eips.ethereum.org/EIPS/eip-5164) on Ethereum.org
- [ERC-5164 Implementation](https://github.com/GenerationSoftware/ERC5164), includes adapters for the native Optimism, Arbitrum and Polygon bridges.  [Audited by Code Arena](https://github.com/code-423n4/2022-12-pooltogether)

## Development

### Installation

You may have to install the following tools to use this repository:

- [Foundry](https://github.com/foundry-rs/foundry) to compile and test contracts
- [direnv](https://direnv.net/) to handle environment variables
- [lcov](https://github.com/linux-test-project/lcov) to generate the code coverage report

Install dependencies:

```
npm i
```

### Env

Copy `.envrc.example` and write down the env variables needed to run this project.

```
cp .envrc.example .envrc
```

Once your env variables are setup, load them with:

```
direnv allow
```

### Compile

Run the following command to compile the contracts:

```
npm run compile
```

### Coverage

Forge is used for coverage, run it with:

```
npm run coverage
```

You can then consult the report by opening `coverage/index.html`:

```
open coverage/index.html
```

### Code quality

[Husky](https://typicode.github.io/husky/#/) is used to run [lint-staged](https://github.com/okonet/lint-staged) and tests when committing.

[Prettier](https://prettier.io) is used to format TypeScript and Solidity code. Use it by running:

```
npm run format
```

[Solhint](https://protofire.github.io/solhint/) is used to lint Solidity files. Run it with:

```
npm run hint
```

### CI

A default Github Actions workflow is setup to execute on push and pull request.

It will build the contracts and run the test coverage.

You can modify it here: [.github/workflows/coverage.yml](.github/workflows/coverage.yml)

For the coverage to work, you will need to setup the `MAINNET_RPC_URL` repository secret in the settings of your Github repository.
