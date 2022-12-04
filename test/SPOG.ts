import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("SPOG", function () {
    async function deploySPOG() {
        const [owner, alice, bob, charlie] = await ethers.getSigners();

        const TestToken = await ethers.getContractFactory("TestToken");
        const testToken = await TestToken.deploy();
        const cashToken = await TestToken.deploy();

        const SPOG = await ethers.getContractFactory("SPOG");
        const spog = await SPOG.deploy(
            "TokenSPOG",
            "TSPOG",
            testToken.address,
            cashToken.address,
            ethers.utils.parseUnits("10", "ether"),
            3600 * 24 * 30,
            300,
        );

        const mintData: [SignerWithAddress, number][] = [[alice, 100], [bob, 50], [charlie, 30]];
        for (const minter of mintData) {
            const [user, amount] = minter;
            await testToken.transfer(
                user.address,
                ethers.utils.parseUnits(amount.toString(), "ether"),
            );
            await testToken.connect(user).approve(spog.address, ethers.constants.MaxUint256);
            await cashToken.transfer(user.address, ethers.utils.parseUnits("10", "ether"));
            await cashToken.connect(user).approve(spog.address, ethers.constants.MaxUint256);
        }

        await spog.connect(alice).stake(await testToken.balanceOf(alice.address));
        await spog.connect(bob).stake(await testToken.balanceOf(bob.address));
        await spog.connect(charlie).stake(await testToken.balanceOf(charlie.address));

        return { spog, testToken, cashToken, owner, alice, bob, charlie};
  }

  describe("Deployment", function () {
    it("should be able to grief", async function () {
        const { spog, testToken, alice, bob, charlie } = await loadFixture(deploySPOG);
        expect(await spog.token()).to.equal(testToken.address);
        await expect(spog.grief()).to.be.revertedWith("still in grief period");

        expect(await spog.balanceOf(alice.address)).to.equal(ethers.utils.parseUnits("100", "ether"));
        expect(await spog.balanceOf(bob.address)).to.equal(ethers.utils.parseUnits("50", "ether"));
        expect(await spog.balanceOf(charlie.address)).to.equal(ethers.utils.parseUnits("30", "ether"));

        await time.increase(await spog.time());

        await spog.grief();
        expect((await spog.voteData(0)).remainingTokenAmount).to.equal("5400000000000000000");

        await spog.connect(alice).vote(0, true);
        expect(
            (await spog.voteData(0)).remainingTokenAmount
        ).to.equal("2400000000000000000");
        await spog.connect(bob).vote(0, true);
        expect(
            (await spog.voteData(0)).remainingTokenAmount
        ).to.equal("900000000000000000");
        await spog.connect(charlie).vote(0, true);
        expect(
            (await spog.voteData(0)).remainingTokenAmount
        ).to.equal(0);

        await expect(spog.connect(alice).claim(0)).to.be.revertedWith("no claim on grief vote");

        await time.increase(await spog.time());
        await spog.grief();
        await spog.connect(alice).vote(1, true);
        await spog.connect(bob).vote(1, true);
        await spog.connect(charlie).vote(1, false);
        expect(
            (await spog.voteData(1)).remainingTokenAmount
        ).to.equal("900000000000000000");
        await time.increase(await spog.time());

        await spog.sell(1);

        await testToken.transfer(alice.address, ethers.utils.parseUnits("100", "ether"));
        await testToken.transfer(bob.address, ethers.utils.parseUnits("100", "ether"));
        await testToken.transfer(charlie.address, ethers.utils.parseUnits("100", "ether"));
        let auctionData = await spog.auctionData(1);
        expect(auctionData.tokenAmount).to.equal("900000000000000000");
        await spog.connect(alice).bid(1, "10000000000");

        auctionData = await spog.auctionData(1);
        expect(auctionData.currentBidder).to.equal(alice.address);

        await time.increase(await spog.time());

        expect(await spog.balanceOf(alice.address)).to.equal("100000000000000000000");
        await spog.finalize(1);
        expect(await spog.balanceOf(alice.address)).to.equal("100900000000000000000");

        const { data: transactionData } = await testToken.populateTransaction.transfer(alice.address, "10000000000");
        await spog.connect(alice).request(testToken.address, transactionData!);

        expect((await spog.voteData(2)).invocation.target).to.equal(testToken.address);

        await spog.connect(alice).voteAndClaim(2, true);
        await spog.connect(bob).voteAndClaim(2, true);
        await spog.connect(charlie).voteAndClaim(2, false);

        await time.increase(await spog.time());
        await spog.sell(2);

        const beforeBalance = await testToken.balanceOf(alice.address);
        await spog.merge(2);
        expect(
            await testToken.balanceOf(alice.address)
        ).to.equal(beforeBalance.add(10000000000));

        // no auction because everyone voted
        await expect(spog.connect(alice).bid(2, "10000000000")).to.be.revertedWith("auction ended");
    });
  });
});
