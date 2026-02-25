import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";

async function expectRevert(txPromise: Promise<unknown>, message: string): Promise<void> {
  await assert.rejects(txPromise, (error: unknown) => {
    const text = String((error as { message?: string })?.message ?? error);
    return text.includes(message);
  });
}

describe("Savings", async function () {
  const { viem } = await network.connect();
  const [owner, alice] = await viem.getWalletClients();

  async function deploy() {
    const savings = await viem.deployContract("Savings");
    const token = await viem.deployContract("MockERC20");
    return { savings, token };
  }

  it("deposits and withdraws ether", async function () {
    const { savings } = await deploy();

    await savings.write.depositEther({ account: owner.account, value: 2n * 10n ** 18n });
    assert.equal(await savings.read.getEtherBalance([owner.account.address]), 2n * 10n ** 18n);

    await savings.write.withdrawEther([5n * 10n ** 17n], { account: owner.account });
    assert.equal(await savings.read.getEtherBalance([owner.account.address]), 15n * 10n ** 17n);
  });

  it("accepts direct receive ether transfers", async function () {
    const { savings } = await deploy();

    await owner.sendTransaction({ to: savings.address, value: 10n ** 18n });

    assert.equal(await savings.read.getEtherBalance([owner.account.address]), 10n ** 18n);
  });

  it("reverts ether flows on invalid amount or insufficient balance", async function () {
    const { savings } = await deploy();

    await expectRevert(
      savings.write.depositEther({ account: owner.account, value: 0n }),
      "Amount must be greater than 0",
    );

    await expectRevert(
      savings.write.withdrawEther([0n], { account: owner.account }),
      "Amount must be greater than 0",
    );

    await expectRevert(
      savings.write.withdrawEther([1n], { account: owner.account }),
      "Insufficient balance",
    );
  });

  it("deposits and withdraws ERC20 tokens", async function () {
    const { savings, token } = await deploy();

    await token.write.mint([owner.account.address, 1000n], { account: owner.account });
    await token.write.approve([savings.address, 700n], { account: owner.account });

    await savings.write.depositToken([token.address, 700n], { account: owner.account });

    assert.equal(
      await savings.read.getTokenBalance([owner.account.address, token.address]),
      700n,
    );

    await savings.write.withdrawToken([token.address, 200n], { account: owner.account });

    assert.equal(
      await savings.read.getTokenBalance([owner.account.address, token.address]),
      500n,
    );
    assert.equal(await token.read.balanceOf([owner.account.address]), 500n);
  });

  it("reverts token flows on invalid amount or insufficient balance", async function () {
    const { savings, token } = await deploy();

    await token.write.mint([owner.account.address, 100n], { account: owner.account });
    await token.write.approve([savings.address, 100n], { account: owner.account });

    await expectRevert(
      savings.write.depositToken([token.address, 0n], { account: owner.account }),
      "Amount must be greater than 0",
    );

    await savings.write.depositToken([token.address, 50n], { account: owner.account });

    await expectRevert(
      savings.write.withdrawToken([token.address, 0n], { account: owner.account }),
      "Amount must be greater than 0",
    );

    await expectRevert(
      savings.write.withdrawToken([token.address, 60n], { account: owner.account }),
      "Insufficient balance",
    );
  });

  it("tracks balances per user", async function () {
    const { savings } = await deploy();

    await savings.write.depositEther({ account: owner.account, value: 5n });
    await savings.write.depositEther({ account: alice.account, value: 11n });

    assert.equal(await savings.read.getEtherBalance([owner.account.address]), 5n);
    assert.equal(await savings.read.getEtherBalance([alice.account.address]), 11n);
  });
});
