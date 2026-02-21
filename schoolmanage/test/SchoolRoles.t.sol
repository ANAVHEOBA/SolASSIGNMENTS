// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {SchoolRoles} from "../src/contract/SchoolRoles.sol";
import {ISchoolRoles} from "../src/interfaces/ISchoolRoles.sol";

contract SchoolRolesTest is Test {
    SchoolRoles internal roles;

    address internal admin = address(0xA11CE);
    address internal otherAdmin = address(0xB0B);
    address internal staff = address(0xCAFE);
    address internal student = address(0xD00D);
    address internal attacker = address(0xBAD);

    function setUp() public {
        vm.prank(admin);
        roles = new SchoolRoles(admin);
    }

    function test_InitialAdminIsSet() public view {
        assertTrue(roles.isAdmin(admin));
        assertEq(uint256(roles.getRole(admin)), uint256(ISchoolRoles.Role.ADMIN));
    }

    function test_NonAdminCannotGrantRole() public {
        vm.prank(attacker);
        vm.expectRevert(SchoolRoles.NotAdmin.selector);
        roles.grantRole(staff, ISchoolRoles.Role.STAFF);
    }

    function test_AdminCanGrantAndRevokeRole() public {
        vm.prank(admin);
        roles.grantRole(staff, ISchoolRoles.Role.STAFF);
        assertTrue(roles.isStaff(staff));

        vm.prank(admin);
        roles.revokeRole(staff);
        assertEq(uint256(roles.getRole(staff)), uint256(ISchoolRoles.Role.NONE));
    }

    function test_CannotGrantNoneRole() public {
        vm.prank(admin);
        vm.expectRevert(SchoolRoles.InvalidRole.selector);
        roles.grantRole(student, ISchoolRoles.Role.NONE);
    }

    function test_CannotRevokeLastAdmin() public {
        vm.prank(admin);
        vm.expectRevert(SchoolRoles.CannotRemoveLastAdmin.selector);
        roles.revokeRole(admin);
    }

    function test_AdminRotationWorks() public {
        vm.startPrank(admin);
        roles.grantRole(otherAdmin, ISchoolRoles.Role.ADMIN);
        roles.revokeRole(admin);
        vm.stopPrank();

        assertTrue(roles.isAdmin(otherAdmin));
        assertFalse(roles.isAdmin(admin));
    }
}
