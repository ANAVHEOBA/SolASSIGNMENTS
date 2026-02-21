// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {SchoolRoles} from "../src/contract/SchoolRoles.sol";
import {StudentRegistry} from "../src/contract/StudentRegistry.sol";
import {FeeManager} from "../src/contract/FeeManager.sol";
import {IStudentRegistry} from "../src/interfaces/IStudentRegistry.sol";
import {IFeeManager} from "../src/interfaces/IFeeManager.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract FeeManagerTest is Test {
    SchoolRoles internal roles;
    StudentRegistry internal students;
    FeeManager internal fees;
    MockERC20 internal token;
    MockERC20 internal token2;

    address internal admin = address(0xA11CE);
    address internal nonAdmin = address(0xBEEF);
    address internal studentA = address(0x3001);

    uint256 internal constant FEE_ID = 1;

    function setUp() public {
        vm.startPrank(admin);
        roles = new SchoolRoles(admin);
        students = new StudentRegistry(address(roles));
        fees = new FeeManager(address(roles), address(students));
        students.createStudent(studentA, 101, "Alice", "ipfs://alice", IStudentRegistry.Level.L200);
        vm.stopPrank();

        token = new MockERC20("MockUSDC", "mUSDC", 6);
        token2 = new MockERC20("MockDAI", "mDAI", 6);
        token.mint(admin, 1_000_000_000);
        token2.mint(admin, 1_000_000_000);
    }

    function test_AdminOnlyFeeConfiguration() public {
        vm.prank(nonAdmin);
        vm.expectRevert(FeeManager.Unauthorized.selector);
        fees.setFee(FEE_ID, "Library Fee", address(token), 100_000000, true);

        vm.prank(admin);
        fees.setFee(FEE_ID, "Library Fee", address(token), 100_000000, true);
        IFeeManager.FeeConfig memory cfg = fees.getFee(FEE_ID);
        assertEq(cfg.token, address(token));
        assertEq(cfg.amount, 100_000000);
        assertTrue(cfg.active);
    }

    function test_SetLevelFeeAndAssignByLevel() public {
        vm.prank(admin);
        fees.setLevelFee(IStudentRegistry.Level.L200, FEE_ID, "Tuition L200", address(token), 150_000000, true);

        vm.prank(admin);
        fees.assignFeeByLevel(studentA, FEE_ID);

        IFeeManager.StudentFee memory sf = fees.getStudentFee(studentA, FEE_ID);
        assertEq(sf.feeId, FEE_ID);
        assertEq(sf.amountDue, 150_000000);
        assertEq(sf.amountPaid, 0);
        assertFalse(sf.settled);
    }

    function test_AssignManualFeeAndTrackPartialThenFullPayment() public {
        vm.startPrank(admin);
        fees.setFee(FEE_ID, "Manual Fee", address(token), 200_000000, true);
        fees.assignFeeToStudent(studentA, FEE_ID, 200_000000);
        token.approve(address(fees), type(uint256).max);
        vm.stopPrank();

        vm.prank(admin);
        fees.payFee(studentA, FEE_ID, 80_000000);
        IFeeManager.StudentFee memory afterPartial = fees.getStudentFee(studentA, FEE_ID);
        assertEq(afterPartial.amountPaid, 80_000000);
        assertFalse(afterPartial.settled);

        vm.prank(admin);
        fees.payFee(studentA, FEE_ID, 120_000000);
        IFeeManager.StudentFee memory afterFull = fees.getStudentFee(studentA, FEE_ID);
        assertEq(afterFull.amountPaid, 200_000000);
        assertTrue(afterFull.settled);
    }

    function test_CannotPayUnassignedOrSettledFee() public {
        vm.startPrank(admin);
        fees.setFee(FEE_ID, "Manual Fee", address(token), 10_000000, true);
        token.approve(address(fees), type(uint256).max);
        vm.stopPrank();

        vm.prank(admin);
        vm.expectRevert(FeeManager.FeeNotAssigned.selector);
        fees.payFee(studentA, FEE_ID, 1_000000);

        vm.startPrank(admin);
        fees.assignFeeToStudent(studentA, FEE_ID, 10_000000);
        fees.payFee(studentA, FEE_ID, 10_000000);
        vm.stopPrank();

        vm.prank(admin);
        vm.expectRevert(FeeManager.FeeAlreadySettled.selector);
        fees.payFee(studentA, FEE_ID, 1_000000);
    }

    function test_FeeAssignRevertsForInactiveFee() public {
        vm.prank(admin);
        fees.setFee(FEE_ID, "Inactive", address(token), 1_000000, false);

        vm.prank(admin);
        vm.expectRevert(FeeManager.FeeInactive.selector);
        fees.assignFeeToStudent(studentA, FEE_ID, 1_000000);
    }

    function test_Vuln_ReassignKeepsOldPaidAmountAcrossTokenChange() public {
        vm.startPrank(admin);
        fees.setFee(FEE_ID, "Term 1", address(token), 200_000000, true);
        fees.assignFeeToStudent(studentA, FEE_ID, 200_000000);
        token.approve(address(fees), type(uint256).max);
        fees.payFee(studentA, FEE_ID, 150_000000);

        fees.setFee(FEE_ID, "Term 2", address(token2), 100_000000, true);
        fees.assignFeeToStudent(studentA, FEE_ID, 100_000000);
        vm.stopPrank();

        IFeeManager.StudentFee memory sf = fees.getStudentFee(studentA, FEE_ID);
        assertEq(sf.amountPaid, 150_000000);
        assertEq(sf.amountDue, 100_000000);
        assertTrue(sf.settled);
    }
}
