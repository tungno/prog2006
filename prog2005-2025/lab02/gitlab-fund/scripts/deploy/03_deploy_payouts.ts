import { ethers } from "hardhat";
import deployFundManager from "./01_deploy_fund_manager";
import deployValidator from "./02_deploy_validator";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);

  // Deploy previous contracts first
  const fundManager = await deployFundManager();
  const validatorMultiSig = await deployValidator();

  console.log("Deploying DeveloperPayouts...");
  const DeveloperPayouts = await ethers.getContractFactory("DeveloperPayouts");
  const developerPayouts = await DeveloperPayouts.deploy(
      fundManager.address,
      validatorMultiSig.address
  );
  await developerPayouts.deployed();

  console.log("\nDeployment Summary:");
  console.log("-------------------");
  console.log("FundManager:", fundManager.address);
  console.log("ValidatorMultiSig:", validatorMultiSig.address);
  console.log("DeveloperPayouts:", developerPayouts.address);

  return {
    fundManager,
    validatorMultiSig,
    developerPayouts
  };
}

if (require.main === module) {
  main()
      .then(() => process.exit(0))
      .catch((error) => {
        console.error(error);
        process.exit(1);
      });
}

export default main;