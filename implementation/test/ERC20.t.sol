// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "../src/ERC20.sol";

contract ERC20Test is Test {
    ERC20 token;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address spender = address(0x5EED);
    uint256 initialSupply = 1_000_000 ether;

    function setUp() public {
        token = new ERC20("Token", "TKN", 18, initialSupply);
    }

    function test_MetadataAndInitialSupply() public view {
        assertEq(token.name(), "Token");
        assertEq(token.symbol(), "TKN");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), initialSupply);
        assertEq(token.balanceOf(address(this)), initialSupply);
    }

    function test_Transfer() public {
        assertTrue(token.transfer(alice, 100 ether));
        assertEq(token.balanceOf(address(this)), initialSupply - 100 ether);
        assertEq(token.balanceOf(alice), 100 ether);
    }

    function testRevert_TransferToZeroAddress() public {
        vm.expectRevert(ERC20.ZeroAddress.selector);
        token.transfer(address(0), 1);
    }

    function testRevert_TransferInsufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert(ERC20.InsufficientBalance.selector);
        token.transfer(bob, 1);
    }

    function test_ApproveAndTransferFrom() public {
        token.transfer(alice, 100 ether);

        vm.prank(alice);
        assertTrue(token.approve(spender, 40 ether));

        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, 25 ether));

        assertEq(token.balanceOf(alice), 75 ether);
        assertEq(token.balanceOf(bob), 25 ether);
        assertEq(token.allowance(alice, spender), 15 ether);
    }

    function testRevert_ApproveZeroAddress() public {
        vm.expectRevert(ERC20.ZeroAddress.selector);
        token.approve(address(0), 1);
    }

    function testRevert_TransferFromInsufficientAllowance() public {
        token.transfer(alice, 10 ether);

        vm.prank(spender);
        vm.expectRevert(ERC20.InsufficientAllowance.selector);
        token.transferFrom(alice, bob, 1);
    }

    function test_InfiniteAllowanceNotDecremented() public {
        token.transfer(alice, 10 ether);

        vm.prank(alice);
        token.approve(spender, type(uint256).max);

        vm.prank(spender);
        token.transferFrom(alice, bob, 3 ether);

        assertEq(token.allowance(alice, spender), type(uint256).max);
    }

    function test_IncreaseAndDecreaseAllowance() public {
        token.approve(spender, 10);
        token.increaseAllowance(spender, 15);
        assertEq(token.allowance(address(this), spender), 25);
        token.decreaseAllowance(spender, 5);
        assertEq(token.allowance(address(this), spender), 20);
    }

    function testRevert_DecreaseAllowanceBelowZero() public {
        token.approve(spender, 3);
        vm.expectRevert(ERC20.InsufficientAllowance.selector);
        token.decreaseAllowance(spender, 4);
    }

    function test_Burn() public {
        token.burn(200 ether);
        assertEq(token.totalSupply(), initialSupply - 200 ether);
        assertEq(token.balanceOf(address(this)), initialSupply - 200 ether);
    }

    function test_BurnFrom() public {
        token.transfer(alice, 50 ether);
        vm.prank(alice);
        token.approve(spender, 30 ether);

        vm.prank(spender);
        token.burnFrom(alice, 20 ether);

        assertEq(token.balanceOf(alice), 30 ether);
        assertEq(token.allowance(alice, spender), 10 ether);
        assertEq(token.totalSupply(), initialSupply - 20 ether);
    }

    function testFuzz_TransferPreservesSupply(uint96 amount) public {
        uint256 value = uint256(amount) % initialSupply;
        token.transfer(alice, value);
        assertEq(token.totalSupply(), initialSupply);
    }
}
