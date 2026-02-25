import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";

async function expectCustomError(txPromise: Promise<unknown>, err: string): Promise<void> {
  await assert.rejects(txPromise, (e: unknown) => String((e as { message?: string })?.message ?? e).includes(err));
}

describe("StaffRegistry", async function () {
  const { viem } = await network.connect();
  const [admin, nonAdmin, staffA] = await viem.getWalletClients();

  async function deploy() {
    const roles = await viem.deployContract("SchoolRoles", [admin.account.address], { account: admin.account });
    const staffRegistry = await viem.deployContract("StaffRegistry", [roles.address], { account: admin.account });
    return { roles, staffRegistry };
  }

  it("allows only admin to create staff", async function () {
    const { staffRegistry } = await deploy();

    await expectCustomError(
      staffRegistry.write.createStaff([staffA.account.address, 10n, 1, "Mr T", "ipfs://mr-t"], {
        account: nonAdmin.account,
      }),
      "Unauthorized",
    );

    await staffRegistry.write.createStaff([staffA.account.address, 10n, 1, "Mr T", "ipfs://mr-t"], {
      account: admin.account,
    });

    const s = await staffRegistry.read.getStaff([staffA.account.address]);
    assert.equal(s.staffId, 10n);
    assert.equal(s.staffType, 1);
    assert.equal(s.status, 1);
  });

  it("rejects invalid type and transition", async function () {
    const { staffRegistry } = await deploy();

    await expectCustomError(
      staffRegistry.write.createStaff([staffA.account.address, 10n, 0, "Mr T", "ipfs://mr-t"], {
        account: admin.account,
      }),
      "InvalidStaffType",
    );

    await staffRegistry.write.createStaff([staffA.account.address, 10n, 1, "Mr T", "ipfs://mr-t"], {
      account: admin.account,
    });

    await expectCustomError(
      staffRegistry.write.unsuspendStaff([staffA.account.address], { account: admin.account }),
      "InvalidStatusTransition",
    );
  });

  it("updates and runs suspend/unsuspend/remove lifecycle", async function () {
    const { staffRegistry } = await deploy();

    await staffRegistry.write.createStaff([staffA.account.address, 10n, 1, "Mr T", "ipfs://mr-t"], {
      account: admin.account,
    });

    await staffRegistry.write.updateStaff([staffA.account.address, 2, "Mr T2", "ipfs://mr-t2"], {
      account: admin.account,
    });
    let s = await staffRegistry.read.getStaff([staffA.account.address]);
    assert.equal(s.fullName, "Mr T2");
    assert.equal(s.staffType, 2);

    await staffRegistry.write.suspendStaff([staffA.account.address], { account: admin.account });
    s = await staffRegistry.read.getStaff([staffA.account.address]);
    assert.equal(s.status, 2);

    await staffRegistry.write.unsuspendStaff([staffA.account.address], { account: admin.account });
    s = await staffRegistry.read.getStaff([staffA.account.address]);
    assert.equal(s.status, 1);

    await staffRegistry.write.removeStaff([staffA.account.address], { account: admin.account });
    s = await staffRegistry.read.getStaff([staffA.account.address]);
    assert.equal(s.status, 3);
  });
});
