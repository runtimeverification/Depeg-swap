import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

import { Address, formatEther, parseEther, WalletClient } from "viem";
import * as helper from "../helper/TestHelper";

describe("FlashSwapRouter", function () {
  let {
    defaultSigner,
    secondSigner,
    signers,
  }: ReturnType<typeof helper.getSigners> = {} as any;

  let depositAmount: bigint;
  let expiry: number;

  let fixture: Awaited<
    ReturnType<typeof helper.ModuleCoreWithInitializedPsmLv>
  >;
  let pool: Awaited<ReturnType<typeof helper.issueNewSwapAssets>>;

  before(async () => {
    const __signers = await hre.viem.getWalletClients();
    ({ defaultSigner, signers } = helper.getSigners(__signers));
    secondSigner = signers[1];
  });

  beforeEach(async () => {
    fixture = await loadFixture(helper.ModuleCoreWithInitializedPsmLv);

    depositAmount = parseEther("100");
    expiry = helper.expiry(1000000);

    await fixture.ra.write.mint([defaultSigner.account.address, depositAmount]);
    await fixture.ra.write.approve([
      fixture.moduleCore.address,
      depositAmount,
    ]);

    pool = await helper.issueNewSwapAssets({
      config: fixture.config.contract.address,
      moduleCore: fixture.moduleCore.address,
      ra: fixture.ra.address,
      expiry,
      factory: fixture.factory.contract.address,
      pa: fixture.pa.address,
    });

    await fixture.moduleCore.write.depositLv([pool.Id, depositAmount]);
  });

  it("should return the correct DS price", async function () {

  });
});
