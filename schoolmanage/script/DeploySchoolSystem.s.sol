// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {SchoolRoles} from "../src/contract/SchoolRoles.sol";
import {StudentRegistry} from "../src/contract/StudentRegistry.sol";
import {StaffRegistry} from "../src/contract/StaffRegistry.sol";
import {FeeManager} from "../src/contract/FeeManager.sol";
import {PayrollManager} from "../src/contract/PayrollManager.sol";

contract DeploySchoolSystemScript is Script {
    SchoolRoles public roles;
    StudentRegistry public studentRegistry;
    StaffRegistry public staffRegistry;
    FeeManager public feeManager;
    PayrollManager public payrollManager;

    function run() external {
        vm.startBroadcast();

        roles = new SchoolRoles(msg.sender);
        studentRegistry = new StudentRegistry(address(roles));
        staffRegistry = new StaffRegistry(address(roles));
        feeManager = new FeeManager(address(roles), address(studentRegistry));
        payrollManager = new PayrollManager(address(roles), address(staffRegistry));

        vm.stopBroadcast();
    }
}
