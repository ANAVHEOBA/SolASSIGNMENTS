// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract SchoolManagement {
    // Grade levels and their fees
    mapping(uint256 => uint256) public gradeFees; // 100, 200, 300, 400 level => fee in wei

    // Student struct
    struct Student {
        address wallet;
        string name;
        uint256 gradeLevel;
        bool feePaid;
        uint256 feePaymentTime;
    }

    // Staff struct
    struct Staff {
        address wallet;
        string name;
        uint256 salary;
        bool salaryPaid;
        uint256 salaryPaymentTime;
    }

    mapping(address => Student) public students;
    mapping(address => Staff) public staff;
    address[] public studentList;
    address[] public staffList;
    mapping(address => bool) public isStudentRegistered;
    mapping(address => bool) public isStaffRegistered;
    address public schoolAdmin;

    event StudentRegistered(address indexed student, string name, uint256 gradeLevel, uint256 fee);
    event StaffRegistered(address indexed staff, string name, uint256 salary);
    event FeePaid(address indexed student, uint256 amount, uint256 timestamp);
    event SalaryPaid(address indexed staff, uint256 amount, uint256 timestamp);

    modifier onlyAdmin() {
        require(msg.sender == schoolAdmin, "Only admin");
        _;
    }

    constructor() {
        schoolAdmin = msg.sender;
        // Set fees for each grade level
        gradeFees[100] = 1 ether;
        gradeFees[200] = 1.5 ether;
        gradeFees[300] = 2 ether;
        gradeFees[400] = 2.5 ether;
    }

    // Register a student; fee is paid separately via payStudentFee
    function registerStudent(address studentAddr, string memory name, uint256 gradeLevel) external onlyAdmin {
        require(studentAddr != address(0), "Invalid address");
        require(gradeLevel >= 100 && gradeLevel <= 400, "Invalid grade level");
        require(gradeLevel % 100 == 0, "Grade level must be 100, 200, 300, or 400");
        require(!isStudentRegistered[studentAddr], "Student already registered");

        uint256 requiredFee = gradeFees[gradeLevel];

        students[studentAddr] = Student(studentAddr, name, gradeLevel, false, 0);
        studentList.push(studentAddr);
        isStudentRegistered[studentAddr] = true;

        emit StudentRegistered(studentAddr, name, gradeLevel, requiredFee);
    }

    // Register staff; salary is paid separately via payStaffSalary
    function registerStaff(address staffAddr, string memory name, uint256 salary) external onlyAdmin {
        require(staffAddr != address(0), "Invalid address");
        require(salary > 0, "Salary must be > 0");
        require(!isStaffRegistered[staffAddr], "Staff already registered");

        staff[staffAddr] = Staff(staffAddr, name, salary, false, 0);
        staffList.push(staffAddr);
        isStaffRegistered[staffAddr] = true;

        emit StaffRegistered(staffAddr, name, salary);
    }

    // Pay student fee and update payment status with timestamp
    function payStudentFee(address studentAddr) external payable onlyAdmin {
        require(isStudentRegistered[studentAddr], "Student not found");
        require(!students[studentAddr].feePaid, "Fee already paid");

        uint256 requiredFee = gradeFees[students[studentAddr].gradeLevel];
        require(msg.value == requiredFee, "Exact payment required");

        students[studentAddr].feePaid = true;
        students[studentAddr].feePaymentTime = block.timestamp;

        emit FeePaid(studentAddr, requiredFee, block.timestamp);
    }

    // Pay staff salary and update payment status with timestamp
    function payStaffSalary(address staffAddr) external payable onlyAdmin {
        require(isStaffRegistered[staffAddr], "Staff not found");
        require(!staff[staffAddr].salaryPaid, "Salary already paid");
        require(msg.value == staff[staffAddr].salary, "Exact payment required");

        staff[staffAddr].salaryPaid = true;
        staff[staffAddr].salaryPaymentTime = block.timestamp;

        (bool success, ) = payable(staffAddr).call{value: msg.value}("");
        require(success, "Salary transfer failed");

        emit SalaryPaid(staffAddr, msg.value, block.timestamp);
    }

    // Get student details
    function getStudent(address studentAddr) external view returns (Student memory) {
        require(students[studentAddr].wallet != address(0), "Student not found");
        return students[studentAddr];
    }

    // Get all students
    function getAllStudents() external view returns (Student[] memory) {
        Student[] memory allStudents = new Student[](studentList.length);
        for (uint256 i = 0; i < studentList.length; i++) {
            allStudents[i] = students[studentList[i]];
        }
        return allStudents;
    }

    // Get all staff
    function getAllStaff() external view returns (Staff[] memory) {
        Staff[] memory allStaff = new Staff[](staffList.length);
        for (uint256 i = 0; i < staffList.length; i++) {
            allStaff[i] = staff[staffList[i]];
        }
        return allStaff;
    }

    // Withdraw funds (admin only)
    function withdraw() external onlyAdmin {
        (bool success, ) = payable(schoolAdmin).call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }
}
