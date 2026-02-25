import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";

async function expectCustomError(txPromise: Promise<unknown>, err: string): Promise<void> {
  await assert.rejects(txPromise, (e: unknown) => String((e as { message?: string })?.message ?? e).includes(err));
}

describe("SchoolRoles", async function () {
  const { viem } = await network.connect();
  const [admin, otherAdmin, staff, attacker] = await viem.getWalletClients();

  async function deploy() {
    return viem.deployContract("SchoolRoles", [admin.account.address], { account: admin.account });
  }

  it("sets initial admin", async function () {
    const roles = await deploy();
    assert.equal(await roles.read.isAdmin([admin.account.address]), true);
    assert.equal(await roles.read.getRole([admin.account.address]), 3);
  });

  it("enforces admin-only role management", async function () {
    const roles = await deploy();

    await expectCustomError(
      roles.write.grantRole([staff.account.address, 2], { account: attacker.account }),
      "NotAdmin",
    );
  });

  it("grants and revokes role", async function () {
    const roles = await deploy();

    await roles.write.grantRole([staff.account.address, 2], { account: admin.account });
    assert.equal(await roles.read.isStaff([staff.account.address]), true);

    await roles.write.revokeRole([staff.account.address], { account: admin.account });
    assert.equal(await roles.read.getRole([staff.account.address]), 0);
  });

  it("blocks invalid role and last admin removal, supports admin rotation", async function () {
    const roles = await deploy();

    await expectCustomError(
      roles.write.grantRole([staff.account.address, 0], { account: admin.account }),
      "InvalidRole",
    );

    await expectCustomError(
      roles.write.revokeRole([admin.account.address], { account: admin.account }),
      "CannotRemoveLastAdmin",
    );

    await roles.write.grantRole([otherAdmin.account.address, 3], { account: admin.account });
    await roles.write.revokeRole([admin.account.address], { account: admin.account });

    assert.equal(await roles.read.isAdmin([otherAdmin.account.address]), true);
    assert.equal(await roles.read.isAdmin([admin.account.address]), false);
  });
});
