// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {SchoolRoles} from "../src/contract/SchoolRoles.sol";
import {StudentRegistry} from "../src/contract/StudentRegistry.sol";
import {IStudentRegistry} from "../src/interfaces/IStudentRegistry.sol";

contract StudentRegistryTest is Test {
    SchoolRoles internal roles;
    StudentRegistry internal students;

    address internal admin = address(0xA11CE);
    address internal nonAdmin = address(0xBEEF);
    address internal studentA = address(0x1001);

    function setUp() public {
        vm.prank(admin);
        roles = new SchoolRoles(admin);
        students = new StudentRegistry(address(roles));
    }

    function test_CreateStudent_AdminOnly() public {
        vm.prank(nonAdmin);
        vm.expectRevert(StudentRegistry.Unauthorized.selector);
        students.createStudent(studentA, 1, "Alice", "ipfs://alice", IStudentRegistry.Level.L100);

        vm.prank(admin);
        students.createStudent(studentA, 1, "Alice", "ipfs://alice", IStudentRegistry.Level.L100);
        IStudentRegistry.Student memory s = students.getStudent(studentA);
        assertEq(s.studentId, 1);
        assertEq(uint256(s.level), uint256(IStudentRegistry.Level.L100));
        assertEq(uint256(s.status), uint256(IStudentRegistry.StudentStatus.ACTIVE));
    }

    function test_CreateStudent_InvalidLevelReverts() public {
        vm.prank(admin);
        vm.expectRevert(StudentRegistry.InvalidLevel.selector);
        students.createStudent(studentA, 1, "Alice", "ipfs://alice", IStudentRegistry.Level.NONE);
    }

    function test_UpdateStudentAndLevel() public {
        vm.startPrank(admin);
        students.createStudent(studentA, 1, "Alice", "ipfs://alice", IStudentRegistry.Level.L100);
        students.updateStudent(studentA, "Alice Doe", "ipfs://alice-v2");
        students.updateStudentLevel(studentA, IStudentRegistry.Level.L200);
        vm.stopPrank();

        IStudentRegistry.Student memory s = students.getStudent(studentA);
        assertEq(s.fullName, "Alice Doe");
        assertEq(s.metadataURI, "ipfs://alice-v2");
        assertEq(uint256(s.level), uint256(IStudentRegistry.Level.L200));
    }

    function test_SuspendUnsuspendRemoveLifecycle() public {
        vm.prank(admin);
        students.createStudent(studentA, 1, "Alice", "ipfs://alice", IStudentRegistry.Level.L100);

        vm.prank(admin);
        students.suspendStudent(studentA);
        assertEq(uint256(students.getStudent(studentA).status), uint256(IStudentRegistry.StudentStatus.SUSPENDED));

        vm.prank(admin);
        students.unsuspendStudent(studentA);
        assertEq(uint256(students.getStudent(studentA).status), uint256(IStudentRegistry.StudentStatus.ACTIVE));

        vm.prank(admin);
        students.removeStudent(studentA);
        assertEq(uint256(students.getStudent(studentA).status), uint256(IStudentRegistry.StudentStatus.REMOVED));
    }

    function test_InvalidTransitionsRevert() public {
        vm.prank(admin);
        students.createStudent(studentA, 1, "Alice", "ipfs://alice", IStudentRegistry.Level.L100);

        vm.prank(admin);
        vm.expectRevert(StudentRegistry.InvalidStatusTransition.selector);
        students.unsuspendStudent(studentA);

        vm.prank(admin);
        students.removeStudent(studentA);

        vm.prank(admin);
        vm.expectRevert(StudentRegistry.StudentAlreadyRemoved.selector);
        students.updateStudent(studentA, "A", "ipfs://a");
    }
}
