import { load } from "ts-dotenv";
import { ethers } from "hardhat";

const env = load({
  WALLET_ADDRESS: String,
  AUTHORIZER_ADDRESS: String,
  CAP: String,
  OPENING_TIME: Number,
  CLOSING_TIME: Number,
  TOKEN_PRICE: Number,
  ACCEPTED_PAYMENT_TOKEN: String,
});

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  // We get the contract to deploy
  const ICO = await ethers.getContractFactory("ICO");
  const instance = await ICO.deploy(
    env.WALLET_ADDRESS,
    env.AUTHORIZER_ADDRESS,
    env.CAP,
    env.OPENING_TIME,
    env.CLOSING_TIME,
    env.TOKEN_PRICE,
    [env.ACCEPTED_PAYMENT_TOKEN]
  );

  await instance.deployed();

  console.log("ICO address:", instance.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
