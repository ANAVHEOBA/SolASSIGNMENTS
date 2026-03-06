# Vault Factory Assignment - Full Design and Implementation Flow

## 1. Goal

Build a system where:

1. A factory deploys one vault per ERC20 token using `CREATE2`.
2. A user deposits a supported token.
3. If a vault for that token does not exist, it is created deterministically.
4. More users can add liquidity by depositing the same token into that vault.
5. Vault deployment mints an NFT whose metadata/image is fully onchain SVG and describes that vault.
6. Tests run on a mainnet fork using real token contracts.

---

## 2. High-Level Architecture

### Core contracts

1. `VaultFactory.sol`
- Entry point for users.
- Stores token => vault mapping.
- Deploys vaults with `CREATE2`.
- Routes deposits into vaults.
- Mints vault NFT on first vault creation.

2. `TokenVault.sol`
- Single-token vault.
- Holds one ERC20 asset.
- Accepts deposits from factory/users.
- Tracks per-user balances and total assets.

3. `VaultNFT.sol`
- ERC721 where tokenId maps to one vault.
- `tokenURI` is fully onchain JSON + SVG.
- SVG displays key vault data (token symbol/name, vault address, total deposited).

4. `VaultSVGRenderer.sol` (optional but recommended)
- Pure/view helper to generate SVG and JSON cleanly.
- Keeps NFT contract simpler and easier to test.

---

## 3. Data Model

### `VaultFactory`
- `mapping(address => address) public vaultOfToken;`
- `mapping(address => bool) public isSupportedToken;` (optional if open to all ERC20)
- `address public immutable vaultNft;`
- `bytes32 public immutable vaultInitCodeHash;` (for deterministic address checks)

### `TokenVault`
- `address public immutable asset;`
- `address public immutable factory;`
- `mapping(address => uint256) public balanceOf;`
- `uint256 public totalDeposited;`

### `VaultNFT`
- `uint256 public nextTokenId;`
- `mapping(uint256 => address) public vaultById;`
- `mapping(address => uint256) public idByVault;`

---

## 4. Main Flows

## 4.1 First deposit for a token (vault creation path)

1. User calls `VaultFactory.deposit(token, amount)`.
2. Factory checks `vaultOfToken[token]`.
3. If empty, factory deploys `TokenVault` with `CREATE2`.
4. Factory stores vault address in mapping.
5. Factory mints vault NFT (1 NFT per vault) to depositor or protocol owner (pick one policy and keep consistent).
6. Factory pulls tokens from user (`transferFrom`) into vault.
7. Vault updates internal accounting (`balanceOf[user]`, `totalDeposited`).
8. Emit events:
- `VaultCreated(token, vault, salt, tokenId)`
- `Deposited(token, vault, user, amount)`

## 4.2 Subsequent deposits (existing vault path)

1. User calls `deposit(token, amount)`.
2. Factory finds existing vault address.
3. Transfer tokens from user to vault.
4. Vault updates balances.
5. Emit `Deposited`.

## 4.3 View deterministic vault before deployment

Expose:

- `function predictVaultAddress(address token) external view returns (address);`

This uses same salt/init code as deploy path and allows frontend/scripts to know vault address before first deposit.

---

## 5. CREATE2 Design

Use token address as part of salt:

- `salt = keccak256(abi.encode(token));`

Vault constructor args should include:

- `asset = token`
- `factory = address(this)`

Important:
- Keep constructor + bytecode stable; changing constructor args/order changes predicted address.
- Add test: `predictVaultAddress(token)` equals actual deployed vault address.

---

## 6. NFT Metadata and Onchain SVG

`tokenURI(tokenId)` should return:

1. Base64-encoded JSON
2. JSON includes Base64-encoded SVG image

Suggested JSON fields:
- `name`: `Vault Position #<id>`
- `description`: `Onchain NFT for token vault`
- `attributes`:
  - token address
  - vault address
  - token symbol
  - total deposited
- `image`: `data:image/svg+xml;base64,<...>`

SVG suggested layout:
- Header: `Vault Position`
- Token symbol + token address
- Vault address (shortened)
- Total deposited amount
- Chain/fork label (optional)

All generated onchain in Solidity (`abi.encodePacked` + Base64).

---

## 7. Security and Validation Rules

1. Reentrancy guard on deposit paths.
2. Reject zero amount deposits.
3. Handle non-standard ERC20 safely using `SafeERC20`.
4. Restrict vault accounting updates to factory (or verify caller/token transfer source model clearly).
5. Prevent duplicate vault deployment for same token.
6. Emit events for all state-changing actions.
7. Add custom errors for gas efficiency and clarity.

---

## 8. Testing Strategy (Mainnet Fork Required)

Use Foundry fork tests with real tokens (example mainnet):
- USDC: `0xA0b86991c6218b36c1d19d4a2e9eb0ce3606eb48`
- DAI: `0x6B175474E89094C44Da98b954EedeAC495271d0F`
- WETH: `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2`

### Test categories

1. `test_CreateVaultOnFirstDeposit()`
- First deposit creates vault + mints NFT + moves funds.

2. `test_SecondDepositUsesSameVault()`
- Multiple users depositing same token use one vault.

3. `test_PredictAddressMatchesDeployedAddress()`
- `CREATE2` determinism validation.

4. `test_RevertOnZeroAmount()`

5. `test_RevertOnUnsupportedToken()` (if allowlist exists)

6. `test_MetadataIsOnchain()`
- `tokenURI` starts with `data:application/json;base64,`
- Decode and validate image field format.

7. `test_TotalDepositedAccounting()`
- Sum of user balances equals vault total.

8. `testFuzz_DepositAmounts()`
- Fuzz valid amount ranges for accounting consistency.

### Fork setup pattern

- In `setUp()`: `vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));`
- Use `deal(token, user, amount)` to fund test users when possible.
- Use `prank(user)` + `approve(factory, amount)` before deposit.

---

## 9. Scripts and Deployment Flow

### `script/DeployVaultSystem.s.sol`

1. Deploy `VaultSVGRenderer` (if separated).
2. Deploy `VaultNFT`.
3. Deploy `VaultFactory` with NFT address.
4. Optionally configure supported tokens.
5. Log addresses.

### `script/DepositExample.s.sol`

1. Read deployed factory.
2. Approve token spend.
3. Call `deposit(token, amount)`.
4. Print predicted and actual vault address.

---

## 10. Suggested Project Structure

```text
src/
  VaultFactory.sol
  TokenVault.sol
  VaultNFT.sol
  VaultSVGRenderer.sol
  interfaces/
    IVaultFactory.sol
    ITokenVault.sol
script/
  DeployVaultSystem.s.sol
  DepositExample.s.sol
test/
  VaultFactoryFork.t.sol
  VaultNFT.t.sol
```

---

## 11. Implementation Order (Practical)

1. Implement `TokenVault` (deposit accounting + events).
2. Implement `VaultFactory` with `CREATE2` + deposit flow.
3. Add deterministic address prediction function and tests.
4. Implement `VaultNFT` basic minting and simple tokenURI.
5. Add full onchain SVG rendering.
6. Add full mainnet-fork tests and edge cases.
7. Add deployment and sample deposit scripts.

---

## 12. Acceptance Checklist

- [ ] First deposit for token deploys vault using `CREATE2`.
- [ ] Same token always maps to same vault.
- [ ] Multiple users can deposit same token into same vault.
- [ ] Vault deployment mints an NFT.
- [ ] NFT metadata and SVG are fully onchain.
- [ ] Mainnet fork tests run using real tokens.
- [ ] Deterministic address prediction is tested and correct.
- [ ] Events and revert conditions are covered by tests.

