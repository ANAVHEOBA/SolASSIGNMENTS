// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";

contract Receiver {
    uint256 public count;
    uint256 public lastValue;

    event Ping(uint256 indexed n, uint256 value);

    function ping(uint256 n) external payable {
        count = n;
        lastValue = msg.value;
        emit Ping(n, msg.value);
    }
}

contract MultiSigWalletTest is Test {
    MultiSigWallet wallet;
    Receiver receiver;

    address owner1 = makeAddr("owner1");
    address owner2 = makeAddr("owner2");
    address owner3 = makeAddr("owner3");
    address outsider = makeAddr("outsider");

    function setUp() public {
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        wallet = new MultiSigWallet(owners, 2);
        receiver = new Receiver();

        vm.deal(address(wallet), 10 ether);
    }

    function test_DeployAndConfig() public view {
        assertEq(wallet.threshold(), 2);
        assertTrue(wallet.isOwner(owner1));
        assertTrue(wallet.isOwner(owner2));
        assertTrue(wallet.isOwner(owner3));
        assertFalse(wallet.isOwner(outsider));
        assertEq(wallet.getTransactionCount(), 0);
    }

    function test_SubmitStoresPendingTransaction() public {
        bytes memory data = abi.encodeCall(Receiver.ping, (7));

        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(address(receiver), 1 ether, data);

        (address to, uint256 value, bytes memory callData, bool executed, uint256 approvals) =
            wallet.transactions(txId);

        assertEq(txId, 0);
        assertEq(to, address(receiver));
        assertEq(value, 1 ether);
        assertEq(callData, data);
        assertFalse(executed);
        assertEq(approvals, 0);
        assertEq(wallet.getTransactionCount(), 1);
    }

    function test_OnlyOwnerCanSubmitAndApprove() public {
        bytes memory data = abi.encodeCall(Receiver.ping, (1));

        vm.prank(outsider);
        vm.expectRevert(MultiSigWallet.NotOwner.selector);
        wallet.submitTransaction(address(receiver), 0, data);

        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(address(receiver), 0, data);

        vm.prank(outsider);
        vm.expectRevert(MultiSigWallet.NotOwner.selector);
        wallet.approveTransaction(txId);
    }

    function test_ApprovalsAccumulateAndPreventDoubleApprove() public {
        bytes memory data = abi.encodeCall(Receiver.ping, (3));

        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(address(receiver), 0.1 ether, data);

        vm.prank(owner1);
        wallet.approveTransaction(txId);
        (, , , , uint256 approvalsAfterFirst) = wallet.transactions(txId);
        assertEq(approvalsAfterFirst, 1);

        vm.prank(owner1);
        vm.expectRevert(MultiSigWallet.TxAlreadyApproved.selector);
        wallet.approveTransaction(txId);

        vm.prank(owner2);
        wallet.approveTransaction(txId);
        (, , , , uint256 approvalsAfterSecond) = wallet.transactions(txId);
        assertEq(approvalsAfterSecond, 2);
    }

    function test_CannotExecuteBeforeThreshold() public {
        bytes memory data = abi.encodeCall(Receiver.ping, (9));

        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(address(receiver), 0.2 ether, data);

        vm.prank(owner1);
        wallet.approveTransaction(txId);

        vm.expectRevert(MultiSigWallet.NotEnoughApprovals.selector);
        wallet.executeTransaction(txId);
    }

    function test_AnyoneCanExecuteOnceThresholdReached() public {
        bytes memory data = abi.encodeCall(Receiver.ping, (42));

        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(address(receiver), 1 ether, data);

        vm.prank(owner1);
        wallet.approveTransaction(txId);

        vm.prank(owner2);
        wallet.approveTransaction(txId);

        uint256 walletBalanceBefore = address(wallet).balance;
        uint256 receiverBalanceBefore = address(receiver).balance;

        vm.prank(outsider);
        wallet.executeTransaction(txId);

        (, , , bool executed, uint256 approvals) = wallet.transactions(txId);

        assertTrue(executed);
        assertEq(approvals, 2);
        assertEq(receiver.count(), 42);
        assertEq(receiver.lastValue(), 1 ether);
        assertEq(address(wallet).balance, walletBalanceBefore - 1 ether);
        assertEq(address(receiver).balance, receiverBalanceBefore + 1 ether);

        vm.expectRevert(MultiSigWallet.TxAlreadyExecuted.selector);
        wallet.executeTransaction(txId);
    }
}
