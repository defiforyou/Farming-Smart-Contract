const hre = require("hardhat");
const FileSystem = require("fs");
const deployInfo = require("../../../deploy.json");

const CONTRACT_NAME = "Lottery";
const REWARD_WALLET = process.env.ADDRESS_2;

async function deploy() {
  // Deploy
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deployer:", deployer.address);
  console.log("Balance:", (await deployer.getBalance()).toString());
  const factory = await hre.ethers.getContractFactory(CONTRACT_NAME);
  console.log("Deploying " + CONTRACT_NAME + "...");
  const contract = await factory.deploy(
    deployInfo.dev2.DFYToken,
    REWARD_WALLET,
    deployInfo.dev2.FarmingFactory,
    1
  );
  await contract.deployed();
  console.log(`${CONTRACT_NAME} deployed address: ${contract.address}`);

  // Write the result to deploy.json
  deployInfo.dev2[CONTRACT_NAME] = contract.address;
  FileSystem.writeFile("deploy.json", JSON.stringify(deployInfo, null, "\t"), err => {
    if (err)
      console.log("Error when trying to write to deploy.json!", err);
    else
      console.log("Information has been written to deploy.json!");
  });
}

deploy();