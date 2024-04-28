import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { SwapContract, Token } from "../typechain-types";

enum SwapStatus {
  Pending,
  Approved,
  Rejected,
  Cancelled,
}

describe("SwapCenter", function () {
  let admin: SignerWithAddress;
  let user_1: SignerWithAddress;
  let user_2: SignerWithAddress;
  let treasury: SignerWithAddress;
  let treasury1: SignerWithAddress;

  let tokenMidTermA: Token;
  let tokenMidTermB: Token;
  let swapContract: SwapContract;
  let swapContractAddr: string;

  const TOKEN_A = {
    name: "MidTermA",
    symbol: "MTA",
    balance: "500000000000000000000", // 500 tokenMidTermA
  };
  const TOKEN_B = {
    name: "MidTermB",
    symbol: "MTB",
    balance: "500000000000000000000", // 500 tokenMidTermB
  };

  const SUCCESS_ORDER = {
    tokenAAmount: "10000000000000000000",
    requestId: 1,
  };

  const TAX = 5;
  const DEFAULT_VALUE = 0;

  before(async () => {
    const signers = await hre.ethers.getSigners();

    admin = signers[0];
    user_1 = signers[1];
    user_2 = signers[2];
    treasury = signers[3];
    treasury1 = signers[4];
  });

  async function fixture() {
    // Deploy Token
    const Token = await hre.ethers.getContractFactory("Token");

    const tokenMidTermA = await Token.connect(admin).deploy(
      TOKEN_A.name,
      TOKEN_A.symbol
    );
    await tokenMidTermA.waitForDeployment();
    const tokenAAddr = await tokenMidTermA.getAddress();

    const tokenMidTermB = await Token.connect(admin).deploy(
      TOKEN_B.name,
      TOKEN_B.symbol
    );
    await tokenMidTermB.waitForDeployment();
    const tokenBAddr = await tokenMidTermB.getAddress();

    // Deploy SwapContract
    const SwapContract = await hre.ethers.getContractFactory("SwapContract");
    const swapContract = await SwapContract.connect(admin).deploy(
      treasury.address
    );
    await swapContract.waitForDeployment();
    const swapContractAddr = await swapContract.getAddress();

    return {
      tokenMidTermA,
      tokenAAddr,
      tokenMidTermB,
      tokenBAddr,
      swapContract,
      swapContractAddr,
    };
  }

  beforeEach(async () => {
    const data = await loadFixture(fixture);
    tokenMidTermA = data.tokenMidTermA;
    tokenMidTermB = data.tokenMidTermB;
    swapContract = data.swapContract;
    swapContractAddr = data.swapContractAddr;

    await tokenMidTermA.connect(admin).mint(user_1.address, TOKEN_A.balance);
    await tokenMidTermB.connect(admin).mint(user_2.address, TOKEN_B.balance);
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await tokenMidTermA.owner()).to.equal(admin.address);
      expect(await tokenMidTermB.owner()).to.equal(admin.address);
      expect(await swapContract.owner()).to.equal(admin.address);
    });

    it("Should receive and store the fund to wallet", async function () {
      expect(await tokenMidTermA.balanceOf(user_1)).to.equal(TOKEN_A.balance);
      expect(await tokenMidTermA.balanceOf(user_2)).to.equal(0);
      expect(await tokenMidTermB.balanceOf(user_1)).to.equal(0);
      expect(await tokenMidTermB.balanceOf(user_2)).to.equal(TOKEN_B.balance);
    });

    it("Should set the right treasury address", async function () {
      expect(await swapContract.treasury()).to.equal(treasury.address);
    });
  });

  describe("Swap", function () {
    const createSwapRequest = async () => {
      await tokenMidTermA
        .connect(user_1)
        .approve(swapContractAddr, SUCCESS_ORDER.tokenAAmount);
      await swapContract
        .connect(user_1)
        .createSwapRequest(user_2.address, SUCCESS_ORDER.tokenAAmount);
    };

    describe("Create swap request", function () {
      it("Should emit created request", async function () {
        await tokenMidTermA
          .connect(user_1)
          .approve(swapContractAddr, SUCCESS_ORDER.tokenAAmount);
        await expect(
          swapContract
            .connect(user_1)
            .createSwapRequest(user_2.address, SUCCESS_ORDER.tokenAAmount)
        )
          .emit(swapContract, "SwapRequestCreated")
          .withArgs(
            SUCCESS_ORDER.requestId,
            user_1.address,
            SUCCESS_ORDER.tokenAAmount
          );
      });
    });

    describe("Approve swap request", function () {
      beforeEach(createSwapRequest);

      it("Should reject wrong request status", async function () {
        await expect(
          swapContract
            .connect(user_2)
            .approveSwapRequest(SUCCESS_ORDER.requestId)
        ).revertedWith("Swap request status is not Pending");
      });

      it("Should reject wrong owner to cancel order", async function () {
        await expect(
          swapContract
            .connect(user_2)
            .cancelSwapRequest(SUCCESS_ORDER.requestId)
        ).revertedWith("Only requester can cancel");
      });

      it("Should emit cancel request", async function () {
        await expect(
          swapContract
            .connect(user_1)
            .cancelSwapRequest(SUCCESS_ORDER.requestId)
        )
          .emit(swapContract, "SwapRequestStatusChanged")
          .withArgs(SUCCESS_ORDER.requestId, SwapStatus.Cancelled);
      });

      it("Should emit reject order", async function () {
        await expect(
          swapContract
            .connect(user_2)
            .rejectSwapRequest(SUCCESS_ORDER.requestId)
        )
          .emit(swapContract, "SwapRequestStatusChanged")
          .withArgs(SUCCESS_ORDER.requestId, SwapStatus.Rejected);

        expect(await tokenMidTermA.balanceOf(user_1)).equal(TOKEN_A.balance);
        expect(await tokenMidTermA.balanceOf(user_2)).equal(DEFAULT_VALUE);
        expect(await tokenMidTermB.balanceOf(user_1)).equal(DEFAULT_VALUE);
        expect(await tokenMidTermB.balanceOf(user_2)).equal(TOKEN_B.balance);
      });
    });
  });

  describe("Tax", function () {
    it("Should emit event set new tax", async function () {
      await expect(swapContract.connect(admin).updateTransactionFee(TAX))
        .emit(swapContract, "TransactionFeeUpdated")
        .withArgs(TAX);
    });
  });

  describe("Treasury", function () {
    it("Should emit event set new treasury address", async function () {
      await expect(
        swapContract.connect(admin).updateTreasury(treasury1.address)
      )
        .emit(swapContract, "TreasuryUpdated")
        .withArgs(treasury1.address);
    });
  });
});
