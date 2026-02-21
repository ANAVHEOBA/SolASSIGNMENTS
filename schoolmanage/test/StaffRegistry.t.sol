// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {SchoolRoles} from "../src/contract/SchoolRoles.sol";
import {StaffRegistry} from "../src/contract/StaffRegistry.sol";
import {IStaffRegistry} from "../src/interfaces/IStaffRegistry.sol";

contract StaffRegistryTest is Test {
    SchoolRoles internal roles;
    StaffRegistry internal staffRegistry;

    address internal admin = address(0xA11CE);
    address internal nonAdmin = address(0xBEEF);
    address internal staffA = address(0x2001);

    function setUp() public {
        vm.prank(admin);
        roles = new SchoolRoles(admin);
        staffRegistry = new StaffRegistry(address(roles));
    }

    function test_CreateStaff_AdminOnly() public {
        vm.prank(nonAdmin);
        vm.expectRevert(StaffRegistry.Unauthorized.selector);
        staffRegistry.createStaff(staffA, 10, IStaffRegistry.StaffType.TEACHER, "Mr T", "ipfs://mr-t");

        vm.prank(admin);
        staffRegistry.createStaff(staffA, 10, IStaffRegistry.StaffType.TEACHER, "Mr T", "ipfs://mr-t");
        IStaffRegistry.Staff memory s = staffRegistry.getStaff(staffA);
        assertEq(s.staffId, 10);
        assertEq(uint256(s.staffType), uint256(IStaffRegistry.StaffType.TEACHER));
        assertEq(uint256(s.status), uint256(IStaffRegistry.StaffStatus.ACTIVE));
    }

    function test_CreateStaff_InvalidTypeReverts() public {
        vm.prank(admin);
        vm.expectRevert(StaffRegistry.InvalidStaffType.selector);
        staffRegistry.createStaff(staffA, 10, IStaffRegistry.StaffType.NONE, "Mr T", "ipfs://mr-t");
    }

    function test_UpdateSuspendUnsuspendRemoveLifecycle() public {
        vm.prank(admin);
        staffRegistry.createStaff(staffA, 10, IStaffRegistry.StaffType.TEACHER, "Mr T", "ipfs://mr-t");

        vm.prank(admin);
        staffRegistry.updateStaff(staffA, IStaffRegistry.StaffType.NON_TEACHING, "Mr T2", "ipfs://mr-t2");
        IStaffRegistry.Staff memory updated = staffRegistry.getStaff(staffA);
        assertEq(updated.fullName, "Mr T2");
        assertEq(uint256(updated.staffType), uint256(IStaffRegistry.StaffType.NON_TEACHING));

        vm.prank(admin);
        staffRegistry.suspendStaff(staffA);
        assertEq(uint256(staffRegistry.getStaff(staffA).status), uint256(IStaffRegistry.StaffStatus.SUSPENDED));

        vm.prank(admin);
        staffRegistry.unsuspendStaff(staffA);
        assertEq(uint256(staffRegistry.getStaff(staffA).status), uint256(IStaffRegistry.StaffStatus.ACTIVE));

        vm.prank(admin);
        staffRegistry.removeStaff(staffA);
        assertEq(uint256(staffRegistry.getStaff(staffA).status), uint256(IStaffRegistry.StaffStatus.REMOVED));
    }

    function test_InvalidTransitionReverts() public {
        vm.prank(admin);
        staffRegistry.createStaff(staffA, 10, IStaffRegistry.StaffType.TEACHER, "Mr T", "ipfs://mr-t");

        vm.prank(admin);
        vm.expectRevert(StaffRegistry.InvalidStatusTransition.selector);
        staffRegistry.unsuspendStaff(staffA);
    }
}
