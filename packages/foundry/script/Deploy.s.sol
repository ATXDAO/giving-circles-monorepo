//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../contracts/YourContract.sol";
import "./DeployHelpers.s.sol";
import {GivingCirclesFactory} from "../contracts/GivingCirclesFactory.sol";
import {GivingCircle} from "../contracts/GivingCircle.sol";
import {Initialization} from "../contracts/Initialization.sol";
import {TestERC20} from "../contracts/TestERC20.sol";

contract DeployScript is ScaffoldETHDeploy {
    error InvalidPrivateKey(string);

    function run() external {
        uint256 deployerPrivateKey = setupLocalhostEnv();
        if (deployerPrivateKey == 0) {
            revert InvalidPrivateKey(
                "You don't have a deployer account. Make sure you have set DEPLOYER_PRIVATE_KEY in .env or use `yarn generate` to generate a new random account"
            );
        }

        address[] memory admins = new address[](1);
        admins[0] = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);
        GivingCirclesFactory yourContract = new GivingCirclesFactory(admins);
        console.logString(
            string.concat(
                "YourContract deployed at: ",
                vm.toString(address(yourContract))
            )
        );

        GivingCircle implementation = new GivingCircle();
        yourContract.setImplementation(address(implementation));

        new TestERC20();

        vm.stopBroadcast();

        /**
         * This function generates the file containing the contracts Abi definitions.
         * These definitions are used to derive the types needed in the custom scaffold-eth hooks, for example.
         * This function should be called last.
         */
        exportDeployments();
    }

    function test() public {}
}
