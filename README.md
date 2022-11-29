# Numoen Core

Contracts for creating a perpetual options market.

## Deployments

`Factory` has been deployed to `0x7c4f274aeec722b8f93ce1a83e52872bcd11f7d3` on the following networks:

- Ethereum Goerli Testnet

## Installation

To install with [Foundry](https://github.com/foundry-rs/foundry):

```bash
forge install numoen/core
```

## Local development

This project uses [Foundry](https://github.com/foundry-rs/foundry) as the development framework.

### Dependencies

```bash
forge install
```

### Compilation

```bash
forge build
```

### Test

```bash
forge test
```

### Deployment

Make sure that the network is defined in foundry.toml, then run:

```bash
sh deploy.sh [network]
```
