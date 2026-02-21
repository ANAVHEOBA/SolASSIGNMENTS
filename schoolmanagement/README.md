## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ source .env
$ forge script script/Counter.s.sol:CounterScript --rpc-url lisk_testnet --broadcast --private-key $PRIVATE_KEY
```

## Lisk Sepolia Deployment

- Network: `Lisk Sepolia`
- RPC URL: `https://rpc.sepolia-api.lisk.com`
- Chain ID: `4202`
- Explorer: `https://sepolia-blockscout.lisk.com`

Required `.env` values:

```shell
DEPLOYER_ADDRESS=<your_wallet_address>
PRIVATE_KEY=<your_private_key>
LISK_TESTNET_RPC_URL=https://rpc.sepolia-api.lisk.com
LISK_TESTNET_CHAIN_ID=4202
```

Live deployment (2026-02-21):

- Contract: `0x17894a080edd17065b92cd39555065127cc7562f`
- Contract URL: `https://sepolia-blockscout.lisk.com/address/0x17894a080edd17065b92cd39555065127cc7562f`
- Tx: `0xf0297f9c836f30a0c6795959fe64dbf28a5db87ea21e7c30e408ca439a87a69f`
- Tx URL: `https://sepolia-blockscout.lisk.com/tx/0xf0297f9c836f30a0c6795959fe64dbf28a5db87ea21e7c30e408ca439a87a69f`

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
