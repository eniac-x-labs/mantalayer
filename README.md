<!--
parent:
  order: false
-->

<div align="center">
  <h1> Manta Layer </h1>
</div>

<div align="center">
  <a href="https://github.com/eniac-x-labs/mantalayer/releases/latest">
    <img alt="Version" src="https://img.shields.io/github/tag/eniac-x-labs/mantalayer.svg" />
  </a>
  <a href="https://github.com/eniac-x-labs/mantalayere/blob/main/LICENSE">
    <img alt="License: Apache-2.0" src="https://img.shields.io/github/license/eniac-x-labs/mantalayer.svg" />
  </a>
</div>

Manta Layer Staking Project

## Installation

For prerequisites and detailed build instructions please read the [Installation](https://github.com/eniac-x-labs/mantalayer/) instructions. Once the dependencies are installed, run:

```bash
git submodule update --init --recursive --remote
```

Or check out the latest [release](https://github.com/eniac-x-labs/mantalayer).

##  Test And Depoly

### test
```
forge test 
```

### Depoly

```
forge script script/TreasureManager.s.sol:TreasureManagerScript --rpc-url $RPC_URL --private-key $PRIVKEY

```


## Community


## Contributing

Looking for a good place to start contributing? Check out some [`good first issues`](https://github.com/eniac-x-labs/mantalayer/issues?q=is%3Aopen+is%3Aissue+label%3A%22good+first+issue%22).

For additional instructions, standards and style guides, please refer to the [Contributing](./CONTRIBUTING.md) document.
