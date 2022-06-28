import { ethers, upgrades } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  // We get the contract to deploy
  const TlandToken = await ethers.getContractFactory("TlandTokenMintable");
  const instance = await upgrades.deployProxy(TlandToken, []);

  await instance.deployed();

  console.log("Token address:", instance.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
