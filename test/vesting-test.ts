import { expect } from "chai";
import { Contract } from "ethers";
import { ethers, upgrades } from "hardhat";

describe("Vesting", function () {
  let vesting: Contract;
  let token: Contract;
  let timestamp: number;

  beforeEach(async function () {
    // Deploy token contract
    const TlandToken = await ethers.getContractFactory("TlandToken");
    token = await upgrades.deployProxy(TlandToken, []);

    // Deploy vesting contract
    timestamp = (await ethers.provider.getBlock("latest")).timestamp;
    const TokenVesting = await ethers.getContractFactory("Vesting");
    const startTime = timestamp + 100;
    const endTime = timestamp + 1200;
    const cliffTime = 100;
    const startPercent = 10;
    vesting = await TokenVesting.deploy(
      startTime,
      endTime,
      cliffTime,
      startPercent,
      token.address
    );
  });

  it("Should return correct withdraw limit amount", async function () {
    const [, user] = await ethers.getSigners();

    // Add beneficiary address in vesting contract
    const addBeneficiariesTx = await vesting.addBeneficiaries(
      [user.address],
      [1000000]
    );
    await addBeneficiariesTx.wait();

    // Check initial values
    expect(await vesting.initialBalances(user.address)).to.equal(1000000);
    expect(await vesting.currentBalances(user.address)).to.equal(1000000);
    expect(await vesting.withdrawalLimit(user.address)).to.equal(0);

    // Increase time by 100
    await ethers.provider.send("evm_mine", [timestamp + 100]);
    expect(await vesting.withdrawalLimit(user.address)).to.equal(100000);

    // Increase time by 200
    await ethers.provider.send("evm_mine", [timestamp + 200]);
    expect(await vesting.withdrawalLimit(user.address)).to.equal(100000);

    // Increase time by 300
    await ethers.provider.send("evm_mine", [timestamp + 300]);
    expect(await vesting.withdrawalLimit(user.address)).to.equal(190000);

    // Increase time by 1100
    await ethers.provider.send("evm_mine", [timestamp + 1100]);
    expect(await vesting.withdrawalLimit(user.address)).to.equal(910000);
  });

  it("Should release funds", async function () {
    const [, user] = await ethers.getSigners();

    // Set token in vesting contract
    const setTokenTx = await vesting.setToken(token.address);
    await setTokenTx.wait();

    // Add beneficiary address in vesting contract
    const addBeneficiariesTx = await vesting.addBeneficiaries(
      [user.address],
      [1000000]
    );
    await addBeneficiariesTx.wait();

    // Transfer tokens to vesting
    (await token.transfer(vesting.address, "1000000000")).wait();

    // Lock vesting
    (await vesting.lock()).wait();

    // Increase time by 300
    await ethers.provider.send("evm_mine", [timestamp + 300]);
    expect(await vesting.withdrawalLimit(user.address)).to.equal(190000);

    // Release tokens
    const releaseTx = await vesting.connect(user).release();
    await releaseTx.wait();

    // Check contract state
    expect(await vesting.withdrawalLimit(user.address)).to.equal(0);
    expect(await vesting.totalWithdrawn(user.address)).to.equal(190000);
    expect(await vesting.initialBalances(user.address)).to.equal(1000000);
    expect(await vesting.currentBalances(user.address)).to.equal(810000);
  });
});
