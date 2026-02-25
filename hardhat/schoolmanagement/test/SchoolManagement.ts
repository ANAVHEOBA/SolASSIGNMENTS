import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";

async function expectRevert(txPromise: Promise<unknown>, marker: string): Promise<void> {
  await assert.rejects(txPromise, (error: unknown) => {
    const text = String((error as { message?: string })?.message ?? error);
    return text.includes(marker);
  });
}

describe("SchoolManagement", async function () {
  const { viem } = await network.connect();
  const [admin, student1, student2, staff1, outsider] = await viem.getWalletClients();

  async function deploy() {
    return viem.deployContract("SchoolManagement", [], { account: admin.account });
  }

  it("registers student, enforces exact fee, and sets payment status", async function () {
    const school = await deploy();

    await school.write.registerStudent([student1.account.address, "John Doe", 100n], {
      account: admin.account,
    });

    await expectRevert(
      school.write.payStudentFee([student1.account.address], {
        account: admin.account,
        value: 5n * 10n ** 17n,
      }),
      "Exact payment required",
    );

    await school.write.payStudentFee([student1.account.address], {
      account: admin.account,
      value: 10n ** 18n,
    });

    const s = await school.read.getStudent([student1.account.address]);
    assert.equal(s.name, "John Doe");
    assert.equal(s.gradeLevel, 100n);
    assert.equal(s.feePaid, true);
    assert.ok(s.feePaymentTime > 0n);
  });

  it("rejects duplicate registration and invalid grade constraints", async function () {
    const school = await deploy();

    await school.write.registerStudent([student1.account.address, "John Doe", 200n], {
      account: admin.account,
    });

    await expectRevert(
      school.write.registerStudent([student1.account.address, "Jane Doe", 200n], {
        account: admin.account,
      }),
      "Student already registered",
    );

    await expectRevert(
      school.write.registerStudent([student2.account.address, "Bob", 250n], {
        account: admin.account,
      }),
      "Grade level must be 100, 200, 300, or 400",
    );

    await expectRevert(
      school.write.registerStudent([student2.account.address, "Bob", 500n], {
        account: admin.account,
      }),
      "Invalid grade level",
    );
  });

  it("registers/pays staff with exact salary and blocks duplicates", async function () {
    const school = await deploy();

    await school.write.registerStaff([staff1.account.address, "Jane Smith", 5n * 10n ** 18n], {
      account: admin.account,
    });

    await expectRevert(
      school.write.payStaffSalary([staff1.account.address], {
        account: admin.account,
        value: 2n * 10n ** 18n,
      }),
      "Exact payment required",
    );

    await school.write.payStaffSalary([staff1.account.address], {
      account: admin.account,
      value: 5n * 10n ** 18n,
    });

    const details = await school.read.staff([staff1.account.address]);
    assert.equal(details[1], "Jane Smith");
    assert.equal(details[2], 5n * 10n ** 18n);
    assert.equal(details[3], true);
    assert.ok(details[4] > 0n);

    await expectRevert(
      school.write.registerStaff([staff1.account.address, "Other", 10n], {
        account: admin.account,
      }),
      "Staff already registered",
    );
  });

  it("admin-only restrictions apply for registration and payment", async function () {
    const school = await deploy();

    await expectRevert(
      school.write.registerStudent([student1.account.address, "A", 100n], { account: outsider.account }),
      "Only admin",
    );

    await expectRevert(
      school.write.registerStaff([staff1.account.address, "S", 1n], { account: outsider.account }),
      "Only admin",
    );

    await school.write.registerStudent([student1.account.address, "A", 100n], { account: admin.account });

    await expectRevert(
      school.write.payStudentFee([student1.account.address], {
        account: outsider.account,
        value: 10n ** 18n,
      }),
      "Only admin",
    );
  });

  it("returns all students and all staff, and allows withdraw", async function () {
    const school = await deploy();

    await school.write.registerStudent([student1.account.address, "John", 100n], { account: admin.account });
    await school.write.registerStudent([student2.account.address, "Jane", 200n], { account: admin.account });
    await school.write.registerStaff([staff1.account.address, "Smith", 3n * 10n ** 18n], {
      account: admin.account,
    });

    const students = await school.read.getAllStudents();
    const staff = await school.read.getAllStaff();

    assert.equal(students.length, 2);
    assert.equal(students[0].name, "John");
    assert.equal(students[1].name, "Jane");
    assert.equal(staff.length, 1);
    assert.equal(staff[0].name, "Smith");

    await school.write.payStudentFee([student1.account.address], {
      account: admin.account,
      value: 10n ** 18n,
    });

    const before = await viem.getBalance({ address: admin.account.address });
    await school.write.withdraw({ account: admin.account });
    const after = await viem.getBalance({ address: admin.account.address });

    assert.ok(after > before);
  });
});
