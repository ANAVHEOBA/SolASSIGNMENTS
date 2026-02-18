// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {SchoolManagement} from "../src/SchoolManagement.sol";

contract SchoolManagementTest is Test {
    SchoolManagement public school;
    address admin = address(0x1);
    address student1 = address(0x2);
    address student2 = address(0x3);
    address staff1 = address(0x4);

    function setUp() public {
        vm.prank(admin);
        school = new SchoolManagement();
    }

    function test_RegisterStudent() public {
        vm.prank(admin);
        school.registerStudent(student1, "John Doe", 100);

        SchoolManagement.Student memory s = school.getStudent(student1);
        assertEq(s.name, "John Doe");
        assertEq(s.gradeLevel, 100);
        assertEq(s.feePaid, false);
    }

    function test_PayStudentFee() public {
        vm.prank(admin);
        school.registerStudent(student1, "John Doe", 100);

        vm.deal(student1, 10 ether);
        vm.prank(student1);
        school.payStudentFee{value: 1 ether}(student1);

        SchoolManagement.Student memory s = school.getStudent(student1);
        assertEq(s.feePaid, true);
        assertGt(s.feePaymentTime, 0);
    }

    function test_PayStudentFeeInsufficientAmount() public {
        vm.prank(admin);
        school.registerStudent(student1, "John Doe", 100);

        vm.deal(student1, 1 ether);
        vm.prank(student1);
        vm.expectRevert("Insufficient payment");
        school.payStudentFee{value: 0.5 ether}(student1);
    }

    function test_RegisterStaff() public {
        vm.prank(admin);
        school.registerStaff(staff1, "Jane Smith", 5 ether);

        (address wallet, string memory name, uint256 salary, bool salaryPaid, uint256 salaryPaymentTime) = school.staff(staff1);
        assertEq(name, "Jane Smith");
        assertEq(salary, 5 ether);
        assertEq(salaryPaid, false);
    }

    function test_PayStaffSalary() public {
        vm.prank(admin);
        school.registerStaff(staff1, "Jane Smith", 5 ether);

        vm.deal(admin, 10 ether);
        vm.prank(admin);
        school.payStaffSalary{value: 5 ether}(staff1);

        (address wallet, string memory name, uint256 salary, bool salaryPaid, uint256 salaryPaymentTime) = school.staff(staff1);
        assertEq(salaryPaid, true);
        assertGt(salaryPaymentTime, 0);
    }

    function test_GetAllStudents() public {
        vm.prank(admin);
        school.registerStudent(student1, "John Doe", 100);

        vm.prank(admin);
        school.registerStudent(student2, "Jane Doe", 200);

        SchoolManagement.Student[] memory students = school.getAllStudents();
        assertEq(students.length, 2);
        assertEq(students[0].name, "John Doe");
        assertEq(students[1].name, "Jane Doe");
    }

    function test_GetAllStaff() public {
        address staff2 = address(0x5);

        vm.prank(admin);
        school.registerStaff(staff1, "Jane Smith", 5 ether);

        vm.prank(admin);
        school.registerStaff(staff2, "Bob Johnson", 3 ether);

        SchoolManagement.Staff[] memory staffMembers = school.getAllStaff();
        assertEq(staffMembers.length, 2);
        assertEq(staffMembers[0].name, "Jane Smith");
        assertEq(staffMembers[1].name, "Bob Johnson");
    }

    function test_GradeLevelPricing() public {
        vm.prank(admin);
        school.registerStudent(student1, "John Doe", 200);

        SchoolManagement.Student memory s = school.getStudent(student1);
        assertEq(s.gradeLevel, 200);

        vm.deal(student1, 10 ether);
        vm.prank(student1);
        school.payStudentFee{value: 1.5 ether}(student1);

        s = school.getStudent(student1);
        assertEq(s.feePaid, true);
    }

    function test_WithdrawFunds() public {
        vm.prank(admin);
        school.registerStudent(student1, "John Doe", 100);

        vm.deal(student1, 10 ether);
        vm.prank(student1);
        school.payStudentFee{value: 1 ether}(student1);

        uint256 balanceBefore = admin.balance;
        vm.prank(admin);
        school.withdraw();

        assertGt(admin.balance, balanceBefore);
    }
}
