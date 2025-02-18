import { ethers } from "hardhat";

async function main() {
  const [deployer, validator1, validator2, validator3] = await ethers.getSigners();

  const initialValidators = [
    validator1.address,
    validator2.address,
    validator3.address
  ];
  const threshold = 2; // 2 out of 3 validators required

  console.log("Deploying ValidatorMultiSig with account:", deployer.address);
  console.log("Initial validators:", initialValidators);
  console.log("Threshold:", threshold);

  const ValidatorMultiSig = await ethers.getContractFactory("ValidatorMultiSig");
  const validatorMultiSig = await ValidatorMultiSig.deploy(initialValidators, threshold);
  await validatorMultiSig.deployed();

  console.log("ValidatorMultiSig deployed to:", validatorMultiSig.address);
  return validatorMultiSig;
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