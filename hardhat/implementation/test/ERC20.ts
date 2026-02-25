import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { getAddress } from "viem";

import { network } from "hardhat";

async function expectCustomError(
  txPromise: Promise<unknown>,
  errorName: string,
): Promise<void> {
  await assert.rejects(txPromise, (error: unknown) => {
    const message = String((error as { message?: string })?.message ?? error);
    return message.includes(errorName);
  });
}

describe("ERC20", async function () {
  const { viem } = await network.connect();
  const [owner, alice, bob, spender] = await viem.getWalletClients();

  const NAME = "Token";
  const SYMBOL = "TKN";
  const DECIMALS = 18;
  const INITIAL_SUPPLY = 1_000_000n * 10n ** 18n;

  async function deployToken() {
    return viem.deployContract("ERC20", [NAME, SYMBOL, DECIMALS, INITIAL_SUPPLY]);
  }

  it("sets metadata and initial supply correctly", async function () {
    const token = await deployToken();

    assert.equal(await token.read.name(), NAME);
    assert.equal(await token.read.symbol(), SYMBOL);
    assert.equal(await token.read.decimals(), DECIMALS);
    assert.equal(await token.read.totalSupply(), INITIAL_SUPPLY);
    assert.equal(await token.read.balanceOf([owner.account.address]), INITIAL_SUPPLY);
  });

  it("transfers tokens and emits Transfer", async function () {
    const token = await deployToken();
    const amount = 100n * 10n ** 18n;

    await viem.assertions.emitWithArgs(
      token.write.transfer([alice.account.address, amount], { account: owner.account }),
      token,
      "Transfer",
      [getAddress(owner.account.address), getAddress(alice.account.address), amount],
    );

    assert.equal(
      await token.read.balanceOf([owner.account.address]),
      INITIAL_SUPPLY - amount,
    );
    assert.equal(await token.read.balanceOf([alice.account.address]), amount);
    assert.equal(await token.read.totalSupply(), INITIAL_SUPPLY);
  });

  it("allows zero-value transfer without changing balances", async function () {
    const token = await deployToken();

    await token.write.transfer([alice.account.address, 0n], { account: owner.account });

    assert.equal(await token.read.balanceOf([owner.account.address]), INITIAL_SUPPLY);
    assert.equal(await token.read.balanceOf([alice.account.address]), 0n);
  });

  it("reverts transfer to zero address", async function () {
    const token = await deployToken();

    await expectCustomError(
      token.write.transfer(["0x0000000000000000000000000000000000000000", 1n], {
        account: owner.account,
      }),
      "ZeroAddress",
    );
  });

  it("reverts transfer with insufficient balance", async function () {
    const token = await deployToken();

    await expectCustomError(
      token.write.transfer([bob.account.address, 1n], { account: alice.account }),
      "InsufficientBalance",
    );
  });

  it("approves spender and overwrites allowance", async function () {
    const token = await deployToken();

    await viem.assertions.emitWithArgs(
      token.write.approve([spender.account.address, 40n], { account: owner.account }),
      token,
      "Approval",
      [getAddress(owner.account.address), getAddress(spender.account.address), 40n],
    );

    await token.write.approve([spender.account.address, 15n], { account: owner.account });

    assert.equal(
      await token.read.allowance([owner.account.address, spender.account.address]),
      15n,
    );
  });

  it("reverts approve for zero address spender", async function () {
    const token = await deployToken();

    await expectCustomError(
      token.write.approve(["0x0000000000000000000000000000000000000000", 1n], {
        account: owner.account,
      }),
      "ZeroAddress",
    );
  });

  it("transferFrom updates balances and allowance", async function () {
    const token = await deployToken();

    await token.write.transfer([alice.account.address, 100n], { account: owner.account });
    await token.write.approve([spender.account.address, 40n], { account: alice.account });

    await token.write.transferFrom([alice.account.address, bob.account.address, 25n], {
      account: spender.account,
    });

    assert.equal(await token.read.balanceOf([alice.account.address]), 75n);
    assert.equal(await token.read.balanceOf([bob.account.address]), 25n);
    assert.equal(
      await token.read.allowance([alice.account.address, spender.account.address]),
      15n,
    );
  });

  it("reverts transferFrom when allowance is insufficient", async function () {
    const token = await deployToken();

    await token.write.transfer([alice.account.address, 10n], { account: owner.account });

    await expectCustomError(
      token.write.transferFrom([alice.account.address, bob.account.address, 1n], {
        account: spender.account,
      }),
      "InsufficientAllowance",
    );
  });

  it("does not decrement max allowance in transferFrom", async function () {
    const token = await deployToken();

    await token.write.transfer([alice.account.address, 10n], { account: owner.account });
    await token.write.approve([spender.account.address, 2n ** 256n - 1n], {
      account: alice.account,
    });

    await token.write.transferFrom([alice.account.address, bob.account.address, 3n], {
      account: spender.account,
    });

    assert.equal(
      await token.read.allowance([alice.account.address, spender.account.address]),
      2n ** 256n - 1n,
    );
  });

  it("increaseAllowance and decreaseAllowance update allowance", async function () {
    const token = await deployToken();

    await token.write.approve([spender.account.address, 10n], { account: owner.account });
    await token.write.increaseAllowance([spender.account.address, 15n], {
      account: owner.account,
    });
    await token.write.decreaseAllowance([spender.account.address, 5n], {
      account: owner.account,
    });

    assert.equal(
      await token.read.allowance([owner.account.address, spender.account.address]),
      20n,
    );
  });

  it("reverts increaseAllowance/decreaseAllowance with zero spender", async function () {
    const token = await deployToken();

    await expectCustomError(
      token.write.increaseAllowance(["0x0000000000000000000000000000000000000000", 1n], {
        account: owner.account,
      }),
      "ZeroAddress",
    );

    await expectCustomError(
      token.write.decreaseAllowance(["0x0000000000000000000000000000000000000000", 1n], {
        account: owner.account,
      }),
      "ZeroAddress",
    );
  });

  it("reverts decreaseAllowance when subtracting more than allowance", async function () {
    const token = await deployToken();

    await token.write.approve([spender.account.address, 3n], { account: owner.account });

    await expectCustomError(
      token.write.decreaseAllowance([spender.account.address, 4n], {
        account: owner.account,
      }),
      "InsufficientAllowance",
    );
  });

  it("burn reduces balance and total supply", async function () {
    const token = await deployToken();
    const burnAmount = 200n * 10n ** 18n;

    await viem.assertions.emitWithArgs(
      token.write.burn([burnAmount], { account: owner.account }),
      token,
      "Transfer",
      [getAddress(owner.account.address), "0x0000000000000000000000000000000000000000", burnAmount],
    );

    assert.equal(
      await token.read.balanceOf([owner.account.address]),
      INITIAL_SUPPLY - burnAmount,
    );
    assert.equal(await token.read.totalSupply(), INITIAL_SUPPLY - burnAmount);
  });

  it("reverts burn when balance is insufficient", async function () {
    const token = await deployToken();

    await expectCustomError(
      token.write.burn([1n], { account: alice.account }),
      "InsufficientBalance",
    );
  });

  it("burnFrom reduces balance, supply, and allowance", async function () {
    const token = await deployToken();

    await token.write.transfer([alice.account.address, 50n], { account: owner.account });
    await token.write.approve([spender.account.address, 30n], { account: alice.account });

    await token.write.burnFrom([alice.account.address, 20n], {
      account: spender.account,
    });

    assert.equal(await token.read.balanceOf([alice.account.address]), 30n);
    assert.equal(await token.read.totalSupply(), INITIAL_SUPPLY - 20n);
    assert.equal(
      await token.read.allowance([alice.account.address, spender.account.address]),
      10n,
    );
  });

  it("reverts burnFrom on insufficient allowance", async function () {
    const token = await deployToken();

    await token.write.transfer([alice.account.address, 10n], { account: owner.account });

    await expectCustomError(
      token.write.burnFrom([alice.account.address, 1n], { account: spender.account }),
      "InsufficientAllowance",
    );
  });

  it("does not decrement max allowance in burnFrom", async function () {
    const token = await deployToken();

    await token.write.transfer([alice.account.address, 10n], { account: owner.account });
    await token.write.approve([spender.account.address, 2n ** 256n - 1n], {
      account: alice.account,
    });

    await token.write.burnFrom([alice.account.address, 3n], { account: spender.account });

    assert.equal(
      await token.read.allowance([alice.account.address, spender.account.address]),
      2n ** 256n - 1n,
    );
  });

  it("keeps allowance unchanged when transferFrom/burnFrom later revert", async function () {
    const token = await deployToken();

    await token.write.transfer([alice.account.address, 5n], { account: owner.account });
    await token.write.approve([spender.account.address, 5n], { account: alice.account });

    await expectCustomError(
      token.write.transferFrom(
        [alice.account.address, "0x0000000000000000000000000000000000000000", 2n],
        { account: spender.account },
      ),
      "ZeroAddress",
    );

    assert.equal(
      await token.read.allowance([alice.account.address, spender.account.address]),
      5n,
    );

    await expectCustomError(
      token.write.burnFrom([alice.account.address, 10n], { account: spender.account }),
      "InsufficientAllowance",
    );

    assert.equal(
      await token.read.allowance([alice.account.address, spender.account.address]),
      5n,
    );
  });
});
