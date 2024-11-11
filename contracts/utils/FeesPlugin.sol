// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {FeesData} from "../common/Structs.sol";
import {ETH_ADDRESS} from "../common/Constants.sol";

abstract contract FeesPlugin {
    FeesData public feesData;

    constructor(FeesData memory feesData_) {
        feesData = feesData_;
    }

    function setFeesData(FeesData memory feesData_) internal {
        feesData = feesData_;
    }

    function getFeesData() public view returns (FeesData memory) {
        return feesData;
    }
}
