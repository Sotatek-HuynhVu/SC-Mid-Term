const { ethers } = require('hardhat');

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log(
        "Deploying contracts with the account:",
        await deployer.getAddress()
    );

    const MyContract = await ethers.getContractFactory("StandardToken");
    const myContract = await MyContract.deploy("Harry", "HAR", "0x63Cc1a5DCadF3CfB96f2044Fe4d0034D903f55bD", { gasLimit: 8000000})
    console.log("Contract address:",  myContract.target);

  }

  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });