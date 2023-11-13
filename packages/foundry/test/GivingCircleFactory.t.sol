// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/YourContract.sol";
import {GivingCirclesFactory} from "../contracts/GivingCirclesFactory.sol";
import {GivingCircle} from "../contracts/GivingCircle.sol";
import {Initialization} from "../contracts/Initialization.sol";
import {TestERC20} from "../contracts/TestERC20.sol";

contract YourContractTest is Test {
    YourContract public yourContract;
    GivingCirclesFactory public factory;

    function setUp() public {
        yourContract = new YourContract(vm.addr(1));
        address[] memory admins = new address[](1);
        admins[0] = vm.addr(1);

        factory = new GivingCirclesFactory(admins);
    }

    function testMe() public view {
        require(factory.hasRole(factory.DEFAULT_ADMIN_ROLE(), vm.addr(1)));
    }

    function testDeployCircle() public deployCircleAndSetAsImplementation {}

    function testCreateCircle()
        public
        setCircleCreator(vm.addr(1))
        deployCircleAndSetAsImplementation
    {
        vm.startPrank(vm.addr(1));

        Initialization.GivingCircleInitialization memory init;
        init.name = "Test Circle";
        init.beansToDispursePerAttendee = 1;

        address[] memory leaders = new address[](1);
        leaders[0] = vm.addr(1);
        init.circleLeaders = leaders;
        factory.createGivingCircle(init);
        vm.stopPrank();

        require(factory.instancesCount() == 1);
    }

    modifier setCircleCreator(address addr) {
        vm.startPrank(vm.addr(1));
        factory.grantRole(factory.CIRCLE_CREATOR_ROLE(), addr);
        vm.stopPrank();
        _;
    }

    modifier deployCircleAndSetAsImplementation() {
        vm.startPrank(vm.addr(1));
        GivingCircle implementation = new GivingCircle();
        factory.setImplementation(address(implementation));
        vm.stopPrank();
        require(address(factory.implementation()) == address(implementation));
        _;
    }
}
