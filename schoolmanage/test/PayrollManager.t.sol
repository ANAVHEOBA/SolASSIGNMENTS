// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {SchoolRoles} from "../src/contract/SchoolRoles.sol";
import {StaffRegistry} from "../src/contract/StaffRegistry.sol";
import {PayrollManager} from "../src/contract/PayrollManager.sol";
import {ISchoolRoles} from "../src/interfaces/ISchoolRoles.sol";
import {IStaffRegistry} from "../src/interfaces/IStaffRegistry.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract PayrollManagerTest is Test {
    SchoolRoles internal roles;
    StaffRegistry internal staffRegistry;
    PayrollManager internal payroll;
    MockERC20 internal token;

    address internal admin = address(0xA11CE);
    address internal nonAdmin = address(0xBEEF);
    address internal staffA = address(0x4001);
    address internal outsider = address(0x4002);

    uint256 internal constant SALARY = 50_000000;
    uint64 internal constant INTERVAL = 1 days;

    function setUp() public {
        vm.startPrank(admin);
        roles = new SchoolRoles(admin);
        staffRegistry = new StaffRegistry(address(roles));
        payroll = new PayrollManager(address(roles), address(staffRegistry));
        staffRegistry.createStaff(staffA, 501, IStaffRegistry.StaffType.TEACHER, "Mr T", "ipfs://mr-t");
        roles.grantRole(staffA, ISchoolRoles.Role.STAFF);
        vm.stopPrank();

        token = new MockERC20("MockUSDC", "mUSDC", 6);
        token.mint(admin, 1_000_000_000);
    }

    function test_AdminOnlySetAndFundAndDirectPay() public {
        vm.prank(nonAdmin);
        vm.expectRevert(PayrollManager.Unauthorized.selector);
        payroll.setStaffSalary(staffA, address(token), SALARY, INTERVAL, true);

        vm.startPrank(admin);
        payroll.setStaffSalary(staffA, address(token), SALARY, INTERVAL, true);
        token.approve(address(payroll), type(uint256).max);
        payroll.fundPayroll(address(token), 500_000000);
        uint256 before = token.balanceOf(staffA);
        payroll.payStaff(staffA, 100_000000);
        vm.stopPrank();

        assertEq(token.balanceOf(staffA), before + 100_000000);
    }

    function test_ClaimSalaryAfterInterval() public {
        vm.startPrank(admin);
        payroll.setStaffSalary(staffA, address(token), SALARY, INTERVAL, true);
        token.approve(address(payroll), type(uint256).max);
        payroll.fundPayroll(address(token), 500_000000);
        vm.stopPrank();

        vm.prank(staffA);
        vm.expectRevert(PayrollManager.NoClaimableSalary.selector);
        payroll.claimSalary();

        vm.warp(block.timestamp + INTERVAL);
        uint256 before = token.balanceOf(staffA);
        vm.prank(staffA);
        payroll.claimSalary();
        assertEq(token.balanceOf(staffA), before + SALARY);
    }

    function test_ClaimRequiresStaffRoleAndActiveStaffStatus() public {
        vm.startPrank(admin);
        payroll.setStaffSalary(staffA, address(token), SALARY, INTERVAL, true);
        token.approve(address(payroll), type(uint256).max);
        payroll.fundPayroll(address(token), 500_000000);
        vm.stopPrank();

        vm.warp(block.timestamp + INTERVAL);

        vm.prank(outsider);
        vm.expectRevert(PayrollManager.Unauthorized.selector);
        payroll.claimSalary();

        vm.prank(admin);
        staffRegistry.suspendStaff(staffA);

        vm.prank(staffA);
        vm.expectRevert(PayrollManager.StaffNotEligible.selector);
        payroll.claimSalary();
    }

    function test_InsufficientPayrollBalanceReverts() public {
        vm.startPrank(admin);
        payroll.setStaffSalary(staffA, address(token), SALARY, INTERVAL, true);
        token.approve(address(payroll), type(uint256).max);
        payroll.fundPayroll(address(token), 10_000000);
        vm.stopPrank();

        vm.prank(admin);
        vm.expectRevert(PayrollManager.InsufficientPayrollBalance.selector);
        payroll.payStaff(staffA, 100_000000);
    }

    function test_Vuln_DoublePayPossibleAfterDirectPay() public {
        vm.startPrank(admin);
        payroll.setStaffSalary(staffA, address(token), SALARY, INTERVAL, true);
        token.approve(address(payroll), type(uint256).max);
        payroll.fundPayroll(address(token), 1_000_000000);
        vm.stopPrank();

        vm.warp(block.timestamp + INTERVAL);

        uint256 before = token.balanceOf(staffA);
        vm.prank(admin);
        payroll.payStaff(staffA, SALARY);

        vm.prank(staffA);
        payroll.claimSalary();

        assertEq(token.balanceOf(staffA), before + (SALARY * 2));
    }
}
