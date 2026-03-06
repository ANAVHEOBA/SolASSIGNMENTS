// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {VaultFactory} from "../src/VaultFactory.sol";
import {VaultNFT} from "../src/VaultNFT.sol";
import {IVaultFactory} from "../src/interfaces/IVaultFactory.sol";
import {IVaultNFT} from "../src/interfaces/IVaultNFT.sol";
import {ITokenVault} from "../src/interfaces/ITokenVault.sol";

interface Vm {
    function envOr(string calldata name, string calldata defaultValue) external returns (string memory);
    function createFork(string calldata urlOrAlias) external returns (uint256);
    function selectFork(uint256 forkId) external;
    function prank(address msgSender) external;
    function deal(address token, address to, uint256 give) external;
    function expectRevert(bytes4) external;
}

interface IERC20Like {
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract VaultFactoryForkTest {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant USDC_WHALE = 0x55FE002aefF02F77364de339a1292923A15844B8;
    address internal constant WETH_WHALE = 0xF977814e90dA44bFA03b6295A0616a897441aceC;

    VaultFactory internal factory;
    bool internal forkEnabled;

    function setUp() public {
        string memory rpc = vm.envOr("MAINNET_RPC_URL", "");
        if (bytes(rpc).length == 0) return;

        uint256 forkId = vm.createFork(rpc);
        vm.selectFork(forkId);
        forkEnabled = true;
        factory = new VaultFactory();
    }

    function test_CreateVaultOnFirstDeposit() public {
        if (!forkEnabled) return;

        address user = address(0xBEEF);
        uint256 amount = 2_000_000; // 2 USDC
        vm.prank(USDC_WHALE);
        IERC20Like(USDC).transfer(user, amount);

        vm.prank(user);
        IERC20Like(USDC).approve(address(factory), amount);

        address predicted = factory.predictVaultAddress(USDC);

        vm.prank(user);
        address vault = factory.deposit(USDC, amount);

        _assertEqAddress(vault, predicted, "vault!=predicted");
        _assertEqAddress(factory.vaultOfToken(USDC), vault, "mapping mismatch");
        _assertEqUint(IERC20Like(USDC).balanceOf(vault), amount, "vault token bal mismatch");
        _assertEqUint(ITokenVault(vault).totalDeposited(), amount, "totalDeposited mismatch");
        _assertEqUint(ITokenVault(vault).balanceOf(user), amount, "user bal mismatch");

        uint256 id = IVaultNFT(factory.vaultNft()).idByVault(vault);
        _assertTrue(id != 0, "nft id not minted");
        _assertEqAddress(VaultNFT(factory.vaultNft()).ownerOf(id), user, "nft owner mismatch");
    }

    function test_SecondDepositUsesSameVault() public {
        if (!forkEnabled) return;

        address userA = address(0xAAA1);
        address userB = address(0xAAA2);
        uint256 amountA = 1_250_000;
        uint256 amountB = 3_500_000;
        vm.prank(USDC_WHALE);
        IERC20Like(USDC).transfer(userA, amountA);
        vm.prank(USDC_WHALE);
        IERC20Like(USDC).transfer(userB, amountB);

        vm.prank(userA);
        IERC20Like(USDC).approve(address(factory), amountA);
        vm.prank(userB);
        IERC20Like(USDC).approve(address(factory), amountB);

        vm.prank(userA);
        address vaultA = factory.deposit(USDC, amountA);
        vm.prank(userB);
        address vaultB = factory.deposit(USDC, amountB);

        _assertEqAddress(vaultA, vaultB, "different vaults for same token");
        _assertEqUint(ITokenVault(vaultA).balanceOf(userA), amountA, "userA accounting mismatch");
        _assertEqUint(ITokenVault(vaultA).balanceOf(userB), amountB, "userB accounting mismatch");
        _assertEqUint(ITokenVault(vaultA).totalDeposited(), amountA + amountB, "total accounting mismatch");
    }

    function test_PredictAddressMatchesDeployedAddress() public {
        if (!forkEnabled) return;

        address user = address(0xCAFE);
        uint256 amount = 0.5 ether;
        vm.prank(WETH_WHALE);
        IERC20Like(WETH).transfer(user, amount);

        address predicted = factory.predictVaultAddress(WETH);
        _assertEqAddress(factory.vaultOfToken(WETH), address(0), "vault unexpectedly exists");

        vm.prank(user);
        IERC20Like(WETH).approve(address(factory), amount);
        vm.prank(user);
        address deployed = factory.deposit(WETH, amount);

        _assertEqAddress(predicted, deployed, "predict mismatch");
    }

    function test_RevertOnZeroAmount() public {
        if (!forkEnabled) return;

        vm.expectRevert(IVaultFactory.InvalidAmount.selector);
        factory.deposit(USDC, 0);
    }

    function test_RevertOnInvalidToken() public {
        if (!forkEnabled) return;

        vm.expectRevert(IVaultFactory.InvalidToken.selector);
        factory.deposit(address(0), 1);
    }

    function test_MetadataIsOnchainDataUri() public {
        if (!forkEnabled) return;

        address user = address(0xD00D);
        uint256 amount = 1_000_000;
        vm.prank(USDC_WHALE);
        IERC20Like(USDC).transfer(user, amount);

        vm.prank(user);
        IERC20Like(USDC).approve(address(factory), amount);
        vm.prank(user);
        address vault = factory.deposit(USDC, amount);

        uint256 id = IVaultNFT(factory.vaultNft()).idByVault(vault);
        string memory uri = VaultNFT(factory.vaultNft()).tokenURI(id);
        _assertTrue(_startsWith(uri, "data:application/json;base64,"), "tokenURI prefix mismatch");
    }

    function _startsWith(string memory s, string memory prefix) internal pure returns (bool) {
        bytes memory a = bytes(s);
        bytes memory b = bytes(prefix);
        if (b.length > a.length) return false;
        for (uint256 i = 0; i < b.length; ++i) {
            if (a[i] != b[i]) return false;
        }
        return true;
    }

    function _assertTrue(bool ok, string memory err) internal pure {
        if (!ok) revert(err);
    }

    function _assertEqAddress(address a, address b, string memory err) internal pure {
        if (a != b) revert(err);
    }

    function _assertEqUint(uint256 a, uint256 b, string memory err) internal pure {
        if (a != b) revert(err);
    }
}

contract VaultFactoryUnitTest {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    VaultFactory internal factory;

    function setUp() public {
        factory = new VaultFactory();
    }

    function test_FeeOnTransferRecordsActualReceived() public {
        FeeOnTransferToken token = new FeeOnTransferToken();
        address user = address(0x11);
        uint256 amount = 1_000e18;

        token.mint(user, amount);

        vm.prank(user);
        token.approve(address(factory), amount);
        vm.prank(user);
        address vault = factory.deposit(address(token), amount);

        uint256 expectedReceived = (amount * (10_000 - token.FEE_BPS())) / 10_000;
        _assertEqUint(token.balanceOf(vault), expectedReceived, "vault balance mismatch");
        _assertEqUint(ITokenVault(vault).totalDeposited(), expectedReceived, "total mismatch");
        _assertEqUint(ITokenVault(vault).balanceOf(user), expectedReceived, "user mismatch");
    }

    function test_RevertOnEoaTokenAddress() public {
        vm.expectRevert(IVaultFactory.InvalidToken.selector);
        factory.deposit(address(0x1234), 1);
    }

    function test_RevertWhenTransferFromReturnsFalse() public {
        FalseTransferToken token = new FalseTransferToken();
        address user = address(0x22);
        token.mint(user, 100e18);

        vm.prank(user);
        token.approve(address(factory), 100e18);

        vm.expectRevert(VaultFactory.TransferFailed.selector);
        vm.prank(user);
        factory.deposit(address(token), 100e18);
    }

    function test_Bytes32SymbolDoesNotBreakTokenURI() public {
        Bytes32SymbolToken token = new Bytes32SymbolToken();
        address user = address(0x33);
        uint256 amount = 5e18;

        token.mint(user, amount);
        vm.prank(user);
        token.approve(address(factory), amount);
        vm.prank(user);
        address vault = factory.deposit(address(token), amount);

        uint256 id = IVaultNFT(factory.vaultNft()).idByVault(vault);
        string memory uri = VaultNFT(factory.vaultNft()).tokenURI(id);
        _assertTrue(_startsWith(uri, "data:application/json;base64,"), "tokenURI not data uri");
    }

    function test_SubsequentDepositsDoNotMintAnotherNft() public {
        MockERC20 token = new MockERC20("Mock", "MOCK");
        address userA = address(0x44);
        address userB = address(0x55);
        uint256 amountA = 7e18;
        uint256 amountB = 3e18;

        token.mint(userA, amountA);
        token.mint(userB, amountB);

        vm.prank(userA);
        token.approve(address(factory), amountA);
        vm.prank(userB);
        token.approve(address(factory), amountB);

        vm.prank(userA);
        address vault = factory.deposit(address(token), amountA);
        uint256 firstId = IVaultNFT(factory.vaultNft()).idByVault(vault);
        _assertTrue(firstId != 0, "first nft missing");
        _assertEqAddress(VaultNFT(factory.vaultNft()).ownerOf(firstId), userA, "first owner mismatch");

        vm.prank(userB);
        factory.deposit(address(token), amountB);

        uint256 sameId = IVaultNFT(factory.vaultNft()).idByVault(vault);
        _assertEqUint(sameId, firstId, "id changed");
        _assertEqAddress(VaultNFT(factory.vaultNft()).ownerOf(firstId), userA, "owner changed unexpectedly");
    }

    function _startsWith(string memory s, string memory prefix) internal pure returns (bool) {
        bytes memory a = bytes(s);
        bytes memory b = bytes(prefix);
        if (b.length > a.length) return false;
        for (uint256 i = 0; i < b.length; ++i) {
            if (a[i] != b[i]) return false;
        }
        return true;
    }

    function _assertTrue(bool ok, string memory err) internal pure {
        if (!ok) revert(err);
    }

    function _assertEqUint(uint256 a, uint256 b, string memory err) internal pure {
        if (a != b) revert(err);
    }

    function _assertEqAddress(address a, address b, string memory err) internal pure {
        if (a != b) revert(err);
    }
}

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public immutable decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }

    function mint(address to, uint256 amount) public {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "insufficient allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(balanceOf[from] >= amount, "insufficient balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
    }
}

contract FeeOnTransferToken is MockERC20 {
    uint256 public constant FEE_BPS = 1000; // 10%

    constructor() MockERC20("Fee Token", "FEE") {}

    function _transfer(address from, address to, uint256 amount) internal override {
        require(balanceOf[from] >= amount, "insufficient balance");
        uint256 fee = (amount * FEE_BPS) / 10_000;
        uint256 received = amount - fee;
        balanceOf[from] -= amount;
        balanceOf[to] += received;
        balanceOf[address(0xFEE)] += fee;
    }
}

contract FalseTransferToken is MockERC20 {
    constructor() MockERC20("False Transfer", "FLT") {}

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        from;
        to;
        amount;
        return false;
    }
}

contract Bytes32SymbolToken {
    string public name = "Bytes32 Token";
    uint8 public immutable decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function symbol() public pure returns (bytes32) {
        return bytes32("B32");
    }

    function mint(address to, uint256 amount) public {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "insufficient allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "insufficient balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
    }
}


//MAINNET_RPC_URL=https://ethereum.publicnode.com forge test --match-test test_PredictAddressMatchesDeployedAddress -vv