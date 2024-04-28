const { ethers } = require("hardhat");

async function main() {
  const [signer] = await ethers.getSigners();
  console.log("Deploying contracts by:", signer.address);

  const Token = await ethers.getContractFactory("Token");
  const SwapContract = await ethers.getContractFactory("SwapContract");

  const midTermA = await Token.connect(signer).deploy("MidTermA", "MTA");
  console.log("MidTermA deployed to Address:", await midTermA.getAddress());

  const midTermB = await Token.connect(signer).deploy("MidTermB", "MTB");
  console.log("MidTermB deployed to Address:", await midTermB.getAddress());

  const swapContract = await SwapContract.connect(signer).deploy(signer.address);
  console.log(
    `Contract deployed to Address: ${await swapContract.getAddress()} and treasury address is ${
      signer.address
    }`
  );
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.log(err);
    process.exit(1);
  });