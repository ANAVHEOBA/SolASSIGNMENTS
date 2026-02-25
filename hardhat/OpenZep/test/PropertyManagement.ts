import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";

async function expectRevert(txPromise: Promise<unknown>, marker: string): Promise<void> {
  await assert.rejects(txPromise, (error: unknown) => {
    const text = String((error as { message?: string })?.message ?? error);
    return text.includes(marker);
  });
}

describe("PropertyManagement", async function () {
  const { viem } = await network.connect();
  const [admin, seller, buyer, other] = await viem.getWalletClients();

  async function deploy() {
    const token = await viem.deployContract("PaymentToken", [1_000_000n]);
    const management = await viem.deployContract("PropertyManagement", [token.address]);
    return { token, management };
  }

  it("constructor sets deployer role flags and token", async function () {
    const { token, management } = await deploy();

    assert.equal(await management.read.paymentToken(), token.address);
    assert.equal(await management.read.admins([admin.account.address]), true);
    assert.equal(await management.read.sellers([admin.account.address]), true);
    assert.equal(await management.read.buyers([admin.account.address]), true);
  });

  it("reverts constructor with zero token", async function () {
    await expectRevert(
      viem.deployContract("PropertyManagement", ["0x0000000000000000000000000000000000000000"]),
      "zero token",
    );
  });

  it("admin manages seller/buyer roles and non-admin is blocked", async function () {
    const { management } = await deploy();

    await expectRevert(
      management.write.setSeller([seller.account.address, true], { account: other.account }),
      "not admin",
    );

    await management.write.setSeller([seller.account.address, true], { account: admin.account });
    await management.write.setBuyer([buyer.account.address, true], { account: admin.account });

    assert.equal(await management.read.sellers([seller.account.address]), true);
    assert.equal(await management.read.buyers([buyer.account.address]), true);
  });

  it("creates properties and rejects duplicate id, zero price, and non-seller", async function () {
    const { management } = await deploy();

    await management.write.setSeller([seller.account.address, true], { account: admin.account });

    await management.write.createProperty([1n, "A", "Lagos", "Desc", 100n], {
      account: seller.account,
    });

    await expectRevert(
      management.write.createProperty([1n, "B", "Abuja", "Desc2", 150n], {
        account: seller.account,
      }),
      "exists",
    );

    await expectRevert(
      management.write.createProperty([2n, "C", "Lagos", "Desc", 0n], {
        account: seller.account,
      }),
      "zero price",
    );

    await expectRevert(
      management.write.createProperty([3n, "D", "Lagos", "Desc", 200n], {
        account: other.account,
      }),
      "not seller",
    );

    const all = await management.read.getAllProperties();
    assert.equal(all.length, 1);
    assert.equal(all[0].id, 1n);
    assert.equal(all[0].isActive, true);
  });

  it("buying property transfers tokens and deactivates listing", async function () {
    const { token, management } = await deploy();

    await management.write.setSeller([seller.account.address, true], { account: admin.account });
    await management.write.setBuyer([buyer.account.address, true], { account: admin.account });

    await token.write.transfer([buyer.account.address, 1000n], { account: admin.account });

    await management.write.createProperty([7n, "Plot 7", "Abuja", "Prime", 400n], {
      account: seller.account,
    });

    await token.write.approve([management.address, 400n], { account: buyer.account });

    const sellerBefore = await token.read.balanceOf([seller.account.address]);
    const buyerBefore = await token.read.balanceOf([buyer.account.address]);

    await management.write.buyProperty([7n], { account: buyer.account });

    assert.equal(await token.read.balanceOf([seller.account.address]), sellerBefore + 400n);
    assert.equal(await token.read.balanceOf([buyer.account.address]), buyerBefore - 400n);

    const all = await management.read.getAllProperties();
    assert.equal(all[0].isActive, false);
  });

  it("reverts buy on not found/inactive/non-buyer", async function () {
    const { management } = await deploy();

    await management.write.setSeller([seller.account.address, true], { account: admin.account });
    await management.write.setBuyer([buyer.account.address, true], { account: admin.account });

    await expectRevert(
      management.write.buyProperty([999n], { account: buyer.account }),
      "not found",
    );

    await management.write.createProperty([8n, "Flat 8", "Lagos", "Sea view", 10n], {
      account: seller.account,
    });
    await management.write.removeProperty([8n], { account: admin.account });

    await expectRevert(
      management.write.buyProperty([8n], { account: buyer.account }),
      "inactive",
    );

    await expectRevert(
      management.write.buyProperty([8n], { account: other.account }),
      "not buyer",
    );
  });
});
