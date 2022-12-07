# Numoen Core

Contracts for creating a perpetual options market.

## Deployments

`Factory` has been deployed to `0x1B327eFf5033922B0f88FC4D56C29d7AF5a8ecdB` on the following networks:

- Ethereum Goerli Testnet
- Arbitrum Mainnet

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
