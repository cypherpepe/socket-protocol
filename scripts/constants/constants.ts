import { ethers } from "ethers";

export const ETH_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
export const MAX_FEES = ethers.utils.parseEther("0.001");

export const feesData = {
  // feesData
  feePoolChain: 421614, // example chain ID
  feePoolToken: ETH_ADDRESS, // example token address
  maxFees: MAX_FEES, // example max fees
};
