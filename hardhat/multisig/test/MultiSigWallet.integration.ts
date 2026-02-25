import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";
import { encodeFunctionData, parseEther } from "viem";

describe("MultiSigWallet integration", async function () {
  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();
  const [owner1, owner2, owner3, outsider] = await viem.getWalletClients();

  it("runs deploy -> submit -> approve -> execute lifecycle", async function () {
    const owners = [
      owner1.account.address,
      owner2.account.address,
      owner3.account.address,
    ] as const;

    const wallet = await viem.deployContract("MultiSigWallet", [owners, 2n], {
      client: { wallet: owner1 },
    });

    const receiver = await viem.deployContract("Receiver", [], {
      client: { wallet: owner1 },
    });

    const walletAsOwner1 = await viem.getContractAt("MultiSigWallet", wallet.address, {
      client: { wallet: owner1 },
    });
    const walletAsOwner2 = await viem.getContractAt("MultiSigWallet", wallet.address, {
      client: { wallet: owner2 },
    });
    const walletAsOutsider = await viem.getContractAt("MultiSigWallet", wallet.address, {
      client: { wallet: outsider },
    });

    const fundTx = await owner1.sendTransaction({
      to: wallet.address,
      value: parseEther("10"),
    });
    await publicClient.waitForTransactionReceipt({ hash: fundTx });

    assert.equal(await wallet.read.threshold(), 2n);
    assert.equal(await wallet.read.isOwner([owners[0]]), true);
    assert.equal(await wallet.read.isOwner([owners[1]]), true);
    assert.equal(await wallet.read.isOwner([owners[2]]), true);
    assert.equal(await wallet.read.isOwner([outsider.account.address]), false);

    const callData = encodeFunctionData({
      abi: receiver.abi,
      functionName: "ping",
      args: [42n],
    });

    await walletAsOwner1.write.submitTransaction([
      receiver.address,
      parseEther("1"),
      callData,
    ]);

    assert.equal(await wallet.read.getTransactionCount(), 1n);

    const txBeforeApproval = await wallet.read.transactions([0n]);
    assert.equal(txBeforeApproval[3], false);
    assert.equal(txBeforeApproval[4], 0n);

    await viem.assertions.revertWithCustomError(
      walletAsOutsider.write.approveTransaction([0n]),
      wallet,
      "NotOwner",
    );

    await walletAsOwner1.write.approveTransaction([0n]);
    await walletAsOwner2.write.approveTransaction([0n]);

    const txAfterApprovals = await wallet.read.transactions([0n]);
    assert.equal(txAfterApprovals[4], 2n);

    const walletBalanceBefore = await publicClient.getBalance({ address: wallet.address });
    const receiverBalanceBefore = await publicClient.getBalance({
      address: receiver.address,
    });

    await walletAsOutsider.write.executeTransaction([0n]);

    const txAfterExecution = await wallet.read.transactions([0n]);
    assert.equal(txAfterExecution[3], true);

    const walletBalanceAfter = await publicClient.getBalance({ address: wallet.address });
    const receiverBalanceAfter = await publicClient.getBalance({
      address: receiver.address,
    });

    assert.equal(walletBalanceAfter, walletBalanceBefore - parseEther("1"));
    assert.equal(receiverBalanceAfter, receiverBalanceBefore + parseEther("1"));
    assert.equal(await receiver.read.count(), 42n);
    assert.equal(await receiver.read.lastValue(), parseEther("1"));

    await viem.assertions.revertWithCustomError(
      wallet.write.executeTransaction([0n]),
      wallet,
      "TxAlreadyExecuted",
    );
  });
});
