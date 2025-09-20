// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/SupplyChain.sol";

contract SupplyChainTest is Test {
    SupplyChain supply;

    address owner = address(0x1);
    address producer = address(0x2);
    address inspector = address(0x3);
    address distributor = address(0x4);
    address retailer = address(0x5);
    address consumer = address(0x6);

    function setUp() public {
        vm.startPrank(owner);
        supply = new SupplyChain();

        // Register roles
        supply.registerProducer(producer, "Producer A");
        supply.registerQualityInspector(inspector, "Inspector A");
        supply.registerDistributor(distributor, "Distributor A");
        supply.registerRetailer(retailer, "Retailer A");
        vm.stopPrank();
    }

    function testRegisterProducer() public {
        vm.startPrank(owner);
        supply.registerProducer(address(0x7), "Producer B");
        assertTrue(supply.isProducerRegistered(address(0x7)));
        vm.stopPrank();
    }

    function testOnlyOwnerCanRegister() public {
        vm.expectRevert("Not owner");
        supply.registerProducer(address(0x8), "Should Fail");
    }

    function testFullProductLifecycle() public {
        // Producer creates product
        vm.startPrank(producer);
        uint256 pid = supply.createProduct(
            "Milk",
            "BATCH-001",
            "Dairy",
            block.timestamp,
            "ipfs://metadata"
        );
        assertEq(pid, 1);

        // Assign inspector
        supply.assignQualityInspector(pid, inspector);
        vm.stopPrank();

        // Inspector certifies and approves
        vm.startPrank(inspector);
        supply.addCertification(pid, "Organic Certified");
        supply.approveQuality(pid, block.timestamp + 7 days);
        vm.stopPrank();

        // Producer assigns distributor
        vm.startPrank(producer);
        supply.assignDistributor(pid, distributor);
        vm.stopPrank();

        // Distributor assigns retailer
        vm.startPrank(distributor);
        supply.assignRetailer(pid, retailer);
        vm.stopPrank();

        // Retailer sells to consumer
        vm.startPrank(retailer);
        supply.sellToConsumer(pid, consumer);
        vm.stopPrank();

        // Check ownership history
        (address[] memory owners, ) = supply.getOwnershipHistory(pid);
        assertEq(owners[0], producer);
        assertEq(owners[1], distributor);
        assertEq(owners[2], retailer);
        assertEq(owners[3], consumer);

        // Check verified
        (, , , , , , bool approved) = supply.getBasicProductInfo(pid);
        assertTrue(approved);
    }

    function testUnauthorizedInspectorCannotApprove() public {
        vm.startPrank(producer);
        uint256 pid = supply.createProduct("Tea", "BATCH-002", "Beverage", block.timestamp, "ipfs://metadata");
        vm.stopPrank();

        vm.startPrank(inspector);
        vm.expectRevert("Not assigned quality inspector for this product");
        supply.approveQuality(pid, block.timestamp + 30 days);
        vm.stopPrank();
    }

    function testEventsOnRegistration() public {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit SupplyChain.ProducerRegistered(address(0x9), "New Producer");
        supply.registerProducer(address(0x9), "New Producer");
        vm.stopPrank();
    }
}
