import { expect } from "chai";
import { ethers, upgrades } from "hardhat";

describe("TlandToken", function () {
  it("Should instantiate token", async function () {
    const TlandToken = await ethers.getContractFactory("TlandToken");
    const token = await upgrades.deployProxy(TlandToken, []);
    await token.deployed();

    const [owner] = await ethers.getSigners();

    expect(await token.balanceOf(owner.address)).to.equal(
      "100000000000000000000000000"
    );
  });
});
