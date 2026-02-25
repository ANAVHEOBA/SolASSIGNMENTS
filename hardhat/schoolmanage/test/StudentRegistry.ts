import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";

async function expectCustomError(txPromise: Promise<unknown>, err: string): Promise<void> {
  await assert.rejects(txPromise, (e: unknown) => String((e as { message?: string })?.message ?? e).includes(err));
}

describe("StudentRegistry", async function () {
  const { viem } = await network.connect();
  const [admin, nonAdmin, studentA] = await viem.getWalletClients();

  async function deploy() {
    const roles = await viem.deployContract("SchoolRoles", [admin.account.address], { account: admin.account });
    const students = await viem.deployContract("StudentRegistry", [roles.address], { account: admin.account });
    return { roles, students };
  }

  it("allows only admin to create student", async function () {
    const { students } = await deploy();

    await expectCustomError(
      students.write.createStudent([studentA.account.address, 1n, "Alice", "ipfs://alice", 1], {
        account: nonAdmin.account,
      }),
      "Unauthorized",
    );

    await students.write.createStudent([studentA.account.address, 1n, "Alice", "ipfs://alice", 1], {
      account: admin.account,
    });

    const s = await students.read.getStudent([studentA.account.address]);
    assert.equal(s.studentId, 1n);
    assert.equal(s.level, 1);
    assert.equal(s.status, 1);
  });

  it("rejects invalid level and invalid transitions", async function () {
    const { students } = await deploy();

    await expectCustomError(
      students.write.createStudent([studentA.account.address, 1n, "Alice", "ipfs://alice", 0], {
        account: admin.account,
      }),
      "InvalidLevel",
    );

    await students.write.createStudent([studentA.account.address, 1n, "Alice", "ipfs://alice", 1], {
      account: admin.account,
    });

    await expectCustomError(
      students.write.unsuspendStudent([studentA.account.address], { account: admin.account }),
      "InvalidStatusTransition",
    );

    await students.write.removeStudent([studentA.account.address], { account: admin.account });

    await expectCustomError(
      students.write.updateStudent([studentA.account.address, "A", "ipfs://a"], { account: admin.account }),
      "StudentAlreadyRemoved",
    );
  });

  it("updates profile/level and supports lifecycle transitions", async function () {
    const { students } = await deploy();

    await students.write.createStudent([studentA.account.address, 1n, "Alice", "ipfs://alice", 1], {
      account: admin.account,
    });
    await students.write.updateStudent([studentA.account.address, "Alice Doe", "ipfs://alice-v2"], {
      account: admin.account,
    });
    await students.write.updateStudentLevel([studentA.account.address, 2], {
      account: admin.account,
    });

    let s = await students.read.getStudent([studentA.account.address]);
    assert.equal(s.fullName, "Alice Doe");
    assert.equal(s.metadataURI, "ipfs://alice-v2");
    assert.equal(s.level, 2);

    await students.write.suspendStudent([studentA.account.address], { account: admin.account });
    s = await students.read.getStudent([studentA.account.address]);
    assert.equal(s.status, 2);

    await students.write.unsuspendStudent([studentA.account.address], { account: admin.account });
    s = await students.read.getStudent([studentA.account.address]);
    assert.equal(s.status, 1);

    await students.write.removeStudent([studentA.account.address], { account: admin.account });
    s = await students.read.getStudent([studentA.account.address]);
    assert.equal(s.status, 3);
  });
});
