# SchoolManage (Foundry)

School management smart contracts with admin-controlled roles, student/staff registries, ERC20 fee handling, and ERC20 payroll.

## Network

- Network: `Lisk Sepolia`
- RPC URL: `https://rpc.sepolia-api.lisk.com`
- Chain ID: `4202`
- Explorer: `https://sepolia-blockscout.lisk.com`

## Contracts

- `SchoolRoles`: role assignment/revocation (`ADMIN`, `STAFF`, `STUDENT`)
- `StudentRegistry`: create/update/suspend/unsuspend/remove students, with level (`L100`-`L500`)
- `StaffRegistry`: create/update/suspend/unsuspend/remove staff
- `FeeManager`: fee config, level fee config, fee assignment, ERC20 fee payment tracking
- `PayrollManager`: salary config, payroll funding, admin payout, staff salary claim

## Project Structure

- `src/contract/` implementation contracts
- `src/interfaces/` interfaces
- `script/DeploySchoolSystem.s.sol` full deployment script
- `test/` comprehensive tests
- `test/mocks/MockERC20.sol` local test ERC20

## Environment

Create `.env`:

```env
DEPLOYER_ADDRESS=0x...
PRIVATE_KEY=0x...
LISK_TESTNET_RPC_URL=https://rpc.sepolia-api.lisk.com
LISK_TESTNET_CHAIN_ID=4202
```

`foundry.toml` uses:

```toml
[rpc_endpoints]
lisk_testnet = "${LISK_TESTNET_RPC_URL}"
```

## Build and Test

```bash
forge build
forge test -vv
```

## Deploy

```bash
source .env
forge script script/DeploySchoolSystem.s.sol:DeploySchoolSystemScript \
  --rpc-url lisk_testnet \
  --broadcast \
  --private-key $PRIVATE_KEY
```

## Live Deployment (2026-02-21)

- `SchoolRoles`: `0x51af2a57941d3369f5ed758cce4d8ac796112fbc`
- `StudentRegistry`: `0xa9ea13d0b8e4c9abf87e7faa713462791ebd5c46`
- `StaffRegistry`: `0x525783d9f283fa94cf9f36a66acdb2d8fbd9ea6b`
- `FeeManager`: `0x92727bf64df512efd4234fc17e127afa3c3f1370`
- `PayrollManager`: `0xda2f1e9d892aa19fa5fdadc316d4df1ba2783bff`

Explorer links:

- SchoolRoles: `https://sepolia-blockscout.lisk.com/address/0x51af2a57941d3369f5ed758cce4d8ac796112fbc`
- StudentRegistry: `https://sepolia-blockscout.lisk.com/address/0xa9ea13d0b8e4c9abf87e7faa713462791ebd5c46`
- StaffRegistry: `https://sepolia-blockscout.lisk.com/address/0x525783d9f283fa94cf9f36a66acdb2d8fbd9ea6b`
- FeeManager: `https://sepolia-blockscout.lisk.com/address/0x92727bf64df512efd4234fc17e127afa3c3f1370`
- PayrollManager: `https://sepolia-blockscout.lisk.com/address/0xda2f1e9d892aa19fa5fdadc316d4df1ba2783bff`

Deployment tx links:

- SchoolRoles tx: `https://sepolia-blockscout.lisk.com/tx/0xb4fa065a2e4c2974f76dbcd55d5dbef2a34c68486597445fb42d5707b098193b`
- StudentRegistry tx: `https://sepolia-blockscout.lisk.com/tx/0xa0461afbb80a7b6b8338e876214efdaf05e729e9b76255778c341fa5f69ea58e`
- StaffRegistry tx: `https://sepolia-blockscout.lisk.com/tx/0xdaa5d53ab1442bf6dc4083146f95644e339adbbd3fa9742a6b2fa96572e7d4d5`
- FeeManager tx: `https://sepolia-blockscout.lisk.com/tx/0x4cbe8da58a67f7b2691bfeee9bc94d4e45a2bdef76b9b516f21d21146976c43c`
- PayrollManager tx: `https://sepolia-blockscout.lisk.com/tx/0x79f8d7b5da2cc18e538fb8d7427eea64c21af409ede5c7f746282ae30ea02f2b`

Artifacts:

- Broadcast JSON: `broadcast/DeploySchoolSystem.s.sol/4202/run-latest.json`

Deployer remaining balance after deployment:

- `0.019999840878005659 ETH`

## Level Fee Configuration (Set On-Chain)

Token used for fees:

- `USDC.e`: `0x0E82fDDAd51cc3ac12b69761C45bBCB9A2Bf3C83`

Configured fee ID:

- `feeId = 1` (tuition)

Configured levels:

- `L100`: `100000000` (100.000000 with 6 decimals)
- `L200`: `150000000` (150.000000 with 6 decimals)
- `L300`: `200000000` (200.000000 with 6 decimals)
- `L400`: `250000000` (250.000000 with 6 decimals)
- `L500`: `300000000` (300.000000 with 6 decimals)

Fee setup transactions:

- L100: `https://sepolia-blockscout.lisk.com/tx/0x5d57109d5284c84eb349dfbfa9927573d0a8eef555aa4cc7a5c7d1d3c9f0a49d`
- L200: `https://sepolia-blockscout.lisk.com/tx/0x41c45d022f14ca74df5f1162626c82567cfcb14239c0b82258dc488609c1509b`
- L300: `https://sepolia-blockscout.lisk.com/tx/0x40d61018d6c89ec7fb4a2bf49f3d33b9372ec02dc555e3c9dce8f2f98d29fc00`
- L400: `https://sepolia-blockscout.lisk.com/tx/0x26727cabe38f02c9015bf647c071f0409c59ce5b965d17a7652e017667e0c9c5`
- L500: `https://sepolia-blockscout.lisk.com/tx/0x52c78375fb273f2cae695d6528c1b97bbc99ee1eed6c95eb97a25c492cfaa93f`
