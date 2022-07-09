const { ethers } = require("hardhat");
const { signTypedMessage } = require("eth-sig-util");
const { fromRpcSig } = require("ethereumjs-util");
const { expect } = require("chai");
const Wallet = require("ethereumjs-wallet").default;

const EIP712Domain = [
  { name: "name", type: "string" },
  { name: "version", type: "string" },
  { name: "chainId", type: "uint256" },
  { name: "verifyingContract", type: "address" },
];

const Whitelist = [{ name: "user", type: "address" }];

describe("ICO", function () {
  let ico;
  let usdtToken;
  let usdcToken;
  const tokenPrice = ethers.utils.parseUnits("0.05", 6);
  const cap = ethers.utils.parseUnits("10000000", 18);

  const name = "ICO";
  const version = "1";
  let chainId;

  const authorizer = Wallet.generate();

  beforeEach(async function () {
    const [, wallet, user1, user2] = await ethers.getSigners();

    const openingTime = (await ethers.provider.getBlock("latest")).timestamp;
    const closingTime = openingTime + 1000;

    // Deploy USDT token
    const Token = await ethers.getContractFactory("ERC20Token");
    usdtToken = await Token.deploy("Tether USD", "USDT", 6);

    // Deploy USDC token
    usdcToken = await Token.deploy("USD Token", "USDC", 6);

    // Transfer tokens to users
    await usdtToken.transfer(
      user1.address,
      ethers.utils.parseUnits("1000000", 6)
    );
    await usdcToken.transfer(
      user1.address,
      ethers.utils.parseUnits("1000000", 6)
    );
    await usdtToken.transfer(
      user2.address,
      ethers.utils.parseUnits("1000000", 6)
    );
    await usdcToken.transfer(
      user2.address,
      ethers.utils.parseUnits("1000000", 6)
    );

    // Deploy ICO
    const ICO = await ethers.getContractFactory("ICOMock");
    ico = await ICO.deploy(
      wallet.address,
      authorizer.getAddressString(),
      cap,
      openingTime,
      closingTime,
      tokenPrice,
      [usdtToken.address, usdcToken.address]
    );

    chainId = (await ico.getChainId()).toNumber();
  });

  it("Should buy tokens", async function () {
    const [, , user1] = await ethers.getSigners();

    // Data used to create signature according to EIP721
    const data = {
      primaryType: "Whitelist",
      types: {
        EIP712Domain: EIP712Domain,
        Whitelist: Whitelist,
      },
      domain: {
        name,
        version,
        chainId,
        verifyingContract: ico.address,
      },
      message: {
        user: user1.address,
      },
    };

    // Create signature
    const signature = signTypedMessage(authorizer.getPrivateKey(), {
      data: data,
    });
    const { v, r, s } = fromRpcSig(signature);

    // Increasing allowance before transfer funds
    await usdtToken
      .connect(user1)
      .increaseAllowance(ico.address, ethers.utils.parseUnits("1000", 6));

    // Buy with permission
    await ico
      .connect(user1)
      .buyWithPermission(
        usdtToken.address,
        ethers.utils.parseUnits("1000", 6),
        v,
        r,
        s
      );

    // Check state
    expect(await ico.contribution(user1.address)).to.deep.equal([
      ethers.utils.parseUnits("1000", 6),
      [usdtToken.address, usdcToken.address],
      [ethers.utils.parseUnits("1000", 6), ethers.utils.parseUnits("0", 6)],
    ]);
    expect(await ico.purchasedTokens(user1.address)).to.equal(
      ethers.utils.parseUnits("20000", 18)
    );
  });
});
