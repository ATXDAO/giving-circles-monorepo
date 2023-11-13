// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./IGivingCircle.sol";
import "./KYCController.sol";
import "./partialIERC20.sol";
import "./Initialization.sol";
import "./Proposals.sol";
import {GivingCircle} from "./GivingCircle.sol";

contract GivingCircleStandalone is GivingCircle {
    constructor(Initialization.GivingCircleInitialization memory init) {
        initialize(init);
    }
}
