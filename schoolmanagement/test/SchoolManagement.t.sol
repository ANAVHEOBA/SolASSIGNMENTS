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

    function test_RegisterStudentWithExactFee() public {
        vm.deal(admin, 10 ether);
        vm.prank(admin);
        school.registerStudent(student1, "John Doe", 100);

        vm.prank(admin);
        school.payStudentFee{value: 1 ether}(student1);

        SchoolManagement.Student memory s = school.getStudent(student1);
        assertEq(s.name, "John Doe");
        assertEq(s.gradeLevel, 100);
        assertEq(s.feePaid, true);
        assertGt(s.feePaymentTime, 0);
    }

    function test_RegisterStudentWithInsufficientFee() public {
        vm.deal(admin, 10 ether);
        vm.prank(admin);
        school.registerStudent(student1, "John Doe", 100);

        vm.prank(admin);
        vm.expectRevert("Exact payment required");
        school.payStudentFee{value: 0.5 ether}(student1);
    }

    function test_RegisterStudentWithExcessFee() public {
        vm.deal(admin, 10 ether);
        vm.prank(admin);
        school.registerStudent(student1, "John Doe", 100);

        vm.prank(admin);
        vm.expectRevert("Exact payment required");
        school.payStudentFee{value: 2 ether}(student1);
    }

    function test_PreventDuplicateStudentRegistration() public {
        vm.deal(admin, 10 ether);
        vm.prank(admin);
        school.registerStudent(student1, "John Doe", 100);

        vm.prank(admin);
        vm.expectRevert("Student already registered");
        school.registerStudent(student1, "Jane Doe", 100);
    }

    function test_RegisterStaffWithExactSalary() public {
        vm.deal(admin, 10 ether);
        uint256 staffBalanceBefore = staff1.balance;

        vm.prank(admin);
        school.registerStaff(staff1, "Jane Smith", 5 ether);

        vm.prank(admin);
        school.payStaffSalary{value: 5 ether}(staff1);

        (, string memory name, uint256 salary, bool salaryPaid, uint256 salaryPaymentTime) = school.staff(staff1);
        assertEq(name, "Jane Smith");
        assertEq(salary, 5 ether);
        assertEq(salaryPaid, true);
        assertGt(salaryPaymentTime, 0);
        assertEq(staff1.balance, staffBalanceBefore + 5 ether);
    }

    function test_RegisterStaffWithInsufficientSalary() public {
        vm.deal(admin, 10 ether);
        vm.prank(admin);
        school.registerStaff(staff1, "Jane Smith", 5 ether);

        vm.prank(admin);
        vm.expectRevert("Exact payment required");
        school.payStaffSalary{value: 2 ether}(staff1);
    }

    function test_RegisterStaffWithExcessSalary() public {
        vm.deal(admin, 10 ether);
        vm.prank(admin);
        school.registerStaff(staff1, "Jane Smith", 5 ether);

        vm.prank(admin);
        vm.expectRevert("Exact payment required");
        school.payStaffSalary{value: 10 ether}(staff1);
    }

    function test_PreventDuplicateStaffRegistration() public {
        vm.deal(admin, 10 ether);
        vm.prank(admin);
        school.registerStaff(staff1, "Jane Smith", 5 ether);

        vm.prank(admin);
        vm.expectRevert("Staff already registered");
        school.registerStaff(staff1, "Bob Jones", 3 ether);
    }

    function test_GetAllStudents() public {
        vm.deal(admin, 20 ether);
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
        vm.deal(admin, 20 ether);

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
        vm.deal(admin, 10 ether);
        vm.prank(admin);
        school.registerStudent(student1, "John Doe", 300);

        vm.prank(admin);
        school.payStudentFee{value: 2 ether}(student1);

        SchoolManagement.Student memory s = school.getStudent(student1);
        assertEq(s.gradeLevel, 300);
        assertEq(s.feePaid, true);
    }

    function test_AdminOnlyCanRegister() public {
        vm.deal(student1, 10 ether);
        vm.prank(student1);
        vm.expectRevert("Only admin");
        school.registerStudent(student1, "John Doe", 100);
    }

    function test_AdminOnlyCanRegisterStaff() public {
        vm.deal(student1, 10 ether);
        vm.prank(student1);
        vm.expectRevert("Only admin");
        school.registerStaff(staff1, "Jane Smith", 5 ether);
    }

    function test_StudentStartsUnpaidThenMarkedPaid() public {
        vm.deal(admin, 10 ether);
        vm.prank(admin);
        school.registerStudent(student1, "John Doe", 100);

        SchoolManagement.Student memory beforePayment = school.getStudent(student1);
        assertEq(beforePayment.feePaid, false);
        assertEq(beforePayment.feePaymentTime, 0);

        vm.prank(admin);
        school.payStudentFee{value: 1 ether}(student1);

        SchoolManagement.Student memory afterPayment = school.getStudent(student1);
        assertEq(afterPayment.feePaid, true);
        assertGt(afterPayment.feePaymentTime, 0);
    }

    function test_StaffStartsUnpaidThenMarkedPaid() public {
        vm.deal(admin, 10 ether);
        vm.prank(admin);
        school.registerStaff(staff1, "Jane Smith", 5 ether);

        (,,, bool salaryPaidBefore, uint256 salaryTimeBefore) = school.staff(staff1);
        assertEq(salaryPaidBefore, false);
        assertEq(salaryTimeBefore, 0);

        vm.prank(admin);
        school.payStaffSalary{value: 5 ether}(staff1);

        (,,, bool salaryPaidAfter, uint256 salaryTimeAfter) = school.staff(staff1);
        assertEq(salaryPaidAfter, true);
        assertGt(salaryTimeAfter, 0);
    }

    function test_WithdrawFunds() public {
        vm.deal(admin, 10 ether);
        vm.prank(admin);
        school.registerStudent(student1, "John Doe", 100);

        vm.prank(admin);
        school.payStudentFee{value: 1 ether}(student1);

        uint256 balanceBefore = admin.balance;
        vm.prank(admin);
        school.withdraw();

        assertGt(admin.balance, balanceBefore);
    }
}
