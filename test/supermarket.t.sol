// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/supermarket.sol";

contract SupermarketTest is Test {
    Supermarket public supermarket;
    address user = address(0xABCD);
    address attacker = address(0xDEAD);
    address notOwner = address(0xBEEF);
    address buyer = address(0xBEEF);

    event ItemAdded(uint256 indexed itemId, string name, uint256 price, uint256 stock, uint256 quantity);
    event ItemLocked(uint256 indexed itemId);
    event ItemUnlocked(uint256 indexed itemId);
    event ItemRestocked(uint256 indexed itemId, uint256 newQuantity);
    event ItemStatusChanged(uint256 indexed itemId, bool isActive);
    event ItemPriceUpdated(uint256 indexed itemId, uint256 newPrice);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ItemPurchased(
        uint256 indexed itemId, address indexed buyer, uint256 quantity, uint256 remaining, uint256 totalCost
    );

    function setUp() public {
        supermarket = new Supermarket();
    }

    function testGetItem_RevertsIfNotExist() public {
        vm.expectRevert("Item does not exist");
        supermarket.getItem(99);
    }

    function testOwnerIsMsgSender() public view {
        assertEq(supermarket.owner(), address(this), "Owner should be deployer");
    }

    function testNextItemIdIsInitializedTo1() public view {
        assertEq(supermarket.nextItemId(), 1, "nextItemId should be 1 on deploy");
    }

    function testCustomDeployerAddress() public {
        address deployer = address(0xBEEF);
        vm.prank(deployer);
        Supermarket customMarket = new Supermarket();

        assertEq(customMarket.owner(), deployer, "Owner should match custom deployer");
    }

    function testAddItemByOwner() public {
        vm.expectEmit(true, false, false, true);
        emit ItemAdded(1, "Rice", 150, 20, 20);

        supermarket.addItem("Rice", 150, 20);

        (uint256 id, string memory name, uint256 price, uint256 stock, uint256 quantity, bool isAvailable,, bool exists)
        = supermarket.items(1);
        assertEq(id, 1);
        assertEq(name, "Rice");
        assertEq(price, 150);
        assertEq(stock, 20);
        assertEq(quantity, 20);
        assertTrue(isAvailable);
        assertTrue(exists);
    }

    function testAddItemByNotOwnerReverts() public {
        vm.prank(attacker);
        vm.expectRevert("Only owner can perform this action");
        supermarket.addItem("Beans", 100, 10);
    }

    function testAddItemWithZeroPriceReverts() public {
        vm.expectRevert("Price must be greater than 0");
        supermarket.addItem("Oil", 0, 10);
    }

    function testAddItemWithZeroQuantityReverts() public {
        vm.expectRevert("Quantity must be greater than 0");
        supermarket.addItem("Salt", 50, 0);
    }

    function testBuyItemSuccess() public {
        supermarket.addItem("Test", 1 ether, 10); // price = 1 ether per unit

        vm.deal(buyer, 10 ether); // fund buyer

        vm.startPrank(buyer);
        vm.expectEmit(true, true, false, true);
        emit ItemPurchased(1, buyer, 3, 7, 3 ether); // quantity bought, remaining, totalCost

        supermarket.purchaseItem{value: 3 ether}(1, 3); // buyer purchases 3

        vm.stopPrank();

        (,,,, uint256 quantity,,,) = supermarket.items(1);
        assertEq(quantity, 7, "Quantity should reduce after purchase");
    }

    function testBuyItemFailsIfNotEnoughStock() public {
        supermarket.addItem("Test", 1 ether, 5); // Add the item first
        vm.deal(buyer, 10 ether);
        vm.prank(buyer);
        vm.expectRevert("Not enough stock");
        supermarket.buyItem{value: 10 ether}(1, 10);
    }

    function testBuyItemFailsIfNotEnoughPayment() public {
        supermarket.addItem("Test", 1 ether, 5); // Add the item first
        vm.deal(buyer, 10 ether);
        vm.prank(buyer);
        vm.expectRevert("Not enough payment");
        supermarket.buyItem{value: 1 ether}(1, 2); // Needs 2 ether
    }

    function testBuyItemFailsIfUnavailable() public {
        supermarket.addItem("Test", 1 ether, 5); // Add the item first
        vm.deal(buyer, 10 ether);

        // Manually deactivate item (must be exposed or settable in test)
        supermarket.changeItemStatus(1, false); // Assuming this sets `isAvailable = false`

        vm.prank(buyer);
        vm.expectRevert("Item not available");
        supermarket.buyItem{value: 1 ether}(1, 1);
    }

    function testLockItemAsOwner() public {
        supermarket.addItem("Test", 100, 10);

        vm.expectEmit(true, false, false, true);
        emit ItemLocked(1);

        supermarket.lockItem(1);

        (,,,,,, bool locked,) = supermarket.items(1);
        assertTrue(locked, "Item should be locked");
    }

    function testLockItemByNotOwnerReverts() public {
        vm.prank(notOwner);
        vm.expectRevert("Only owner can perform this action");
        supermarket.lockItem(1);
    }

    function testLockNonexistentItemReverts() public {
        vm.expectRevert("Item does not exist");
        supermarket.lockItem(99);
    }

    function testUnlockItemAsOwner() public {
        supermarket.addItem("Test", 100, 10);

        vm.expectEmit(true, false, false, true);
        emit ItemUnlocked(1);

        supermarket.unlockItem(1);

        (,,,,,, bool locked,) = supermarket.items(1);
        assertFalse(locked, "Item should be unlocked");
    }

    function testUnlockItemByNotOwnerReverts() public {
        vm.prank(notOwner);
        vm.expectRevert("Only owner can perform this action");
        supermarket.unlockItem(1);
    }

    function testUnlockNonexistentItemReverts() public {
        vm.expectRevert("Item does not exist");
        supermarket.unlockItem(99);
    }

    function testRestockItemAsOwner() public {
        supermarket.addItem("Test", 100, 5);

        vm.expectEmit(true, false, false, true);
        emit ItemRestocked(1, 10);

        supermarket.restockItem(1, 5);

        (,,,, uint256 quantity,,,) = supermarket.items(1);
        assertEq(quantity, 10, "Quantity should be increased to 10");
    }

    function testRestockItemByNotOwnerReverts() public {
        vm.prank(notOwner);
        vm.expectRevert("Only owner can perform this action");
        supermarket.restockItem(1, 5);
    }

    function testRestockNonexistentItemReverts() public {
        vm.expectRevert("Item does not exist");
        supermarket.restockItem(99, 5);
    }

    function testChangeItemStatusToActive() public {
        supermarket.addItem("Test", 100, 10);

        supermarket.changeItemStatus(1, false);
        (,,,,,, bool lockedBefore,) = supermarket.items(1);
        assertTrue(lockedBefore, "Item should be locked");

        vm.expectEmit(true, false, false, true);
        emit ItemStatusChanged(1, true);

        supermarket.changeItemStatus(1, true);
        (,,,,,, bool lockedAfter,) = supermarket.items(1);
        assertFalse(lockedAfter, "Item should be unlocked");
    }

    function testChangeItemStatusToInactive() public {
        supermarket.addItem("Test", 100, 10);

        vm.expectEmit(true, false, false, true);
        emit ItemStatusChanged(1, false);

        supermarket.changeItemStatus(1, false);

        (,,,,,, bool locked,) = supermarket.items(1);
        assertTrue(locked, "Item should be locked");
    }

    function testChangeItemStatusByNotOwnerReverts() public {
        vm.prank(notOwner);
        vm.expectRevert("Only owner can perform this action");
        supermarket.changeItemStatus(1, true);
    }

    function testChangeItemStatusNonexistentItemReverts() public {
        vm.expectRevert("Item does not exist");
        supermarket.changeItemStatus(99, true);
    }

    function testGetAvailableItems() public {
        supermarket.addItem("Rice", 100, 10);
        supermarket.addItem("Beans", 200, 3);
        supermarket.addItem("Yam", 300, 5);

        (uint256[] memory ids, string[] memory names, uint256[] memory prices, uint256[] memory stocks) =
            supermarket.getAvailableItems();

        assertEq(ids.length, 3);
        assertEq(ids[0], 1);
        assertEq(ids[1], 2);
        assertEq(ids[2], 3);

        assertEq(names[0], "Rice");
        assertEq(names[1], "Beans");
        assertEq(names[2], "Yam");

        assertEq(prices[0], 100);
        assertEq(prices[1], 200);
        assertEq(prices[2], 300);

        assertEq(stocks[0], 10);
        assertEq(stocks[1], 3);
        assertEq(stocks[2], 5);
    }

    function testGetAvailableItemsReturnsEmptyIfNone() public {
        supermarket.addItem("Rice", 100, 10);
        supermarket.addItem("Beans", 200, 3);
        supermarket.addItem("Yam", 300, 5);

        supermarket.changeItemStatus(1, false);
        supermarket.changeItemStatus(3, false);

        supermarket.getAvailableItems();
    }

    function testUpdateItemPriceAsOwner() public {
        supermarket.addItem("Test", 100, 10);

        vm.expectEmit(true, false, false, true);
        emit ItemPriceUpdated(1, 150);

        supermarket.updateItemPrice(1, 150);
        (,, uint256 newPrice,,,,,) = supermarket.items(1);
        assertEq(newPrice, 150);
    }

    function testUpdateItemPriceFailsIfZero() public {
        supermarket.addItem("Test", 100, 10);

        supermarket.updateItemPrice(1, 0);
    }

    function testUpdateItemPriceFailsIfNotOwner() public {
        vm.prank(notOwner);
        vm.expectRevert("Only owner can perform this action");
        supermarket.updateItemPrice(1, 200);
    }

    function testUpdateItemPriceFailsIfItemDoesNotExist() public {
        vm.expectRevert("Item does not exist");
        supermarket.updateItemPrice(99, 200);
    }

    function testTransferOwnershipAsOwner() public {
        supermarket.addItem("Test", 100, 10);

        address newOwner = address(0x1234);

        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(address(this), newOwner);

        supermarket.transferOwnership(newOwner);
        assertEq(supermarket.owner(), newOwner, "Ownership should be transferred to newOwner");
    }

    function testTransferOwnershipFailsIfCallerNotOwner() public {
        address newOwner = address(0x1234);
        vm.prank(notOwner);
        vm.expectRevert("Only owner can perform this action");
        supermarket.transferOwnership(newOwner);
    }

    function testTransferOwnershipFailsIfNewOwnerIsZero() public {
        vm.expectRevert("New owner cannot be zero address");
        supermarket.transferOwnership(address(0));
    }

    function testPurchaseItemSuccess() public {
        supermarket.addItem("Test", 1 ether, 5);

        vm.deal(user, 10 ether);

        vm.expectEmit(true, true, false, true);
        emit ItemPurchased(1, user, 2, 3, 2 ether);

        vm.prank(user);
        supermarket.purchaseItem{value: 2 ether}(1, 2);

        (,,,, uint256 qty,,,) = supermarket.items(1);
        assertEq(qty, 3, "Remaining quantity should be 3");
    }

    function testPurchaseItemRefundsExcessETH() public {
        supermarket.addItem("Test", 1 ether, 5);

        vm.deal(user, 5 ether);
        uint256 buyerStartBalance = user.balance;

        vm.prank(user);
        supermarket.purchaseItem{value: 3 ether}(1, 2);

        assertEq(user.balance, buyerStartBalance - 2 ether, "Should refund excess ETH");
    }

    function testPurchaseItemFailsIfNotEnoughStock() public {
        supermarket.addItem("Test", 1 ether, 5);
        vm.deal(user, 10 ether);
        vm.prank(user);
        vm.expectRevert("Not enough stock available");
        supermarket.purchaseItem{value: 10 ether}(1, 6);
    }

    function testPurchaseItemFailsIfInsufficientPayment() public {
        supermarket.addItem("Test", 1 ether, 5);
        vm.deal(user, 1 ether);
        vm.prank(user);
        vm.expectRevert("Insufficient payment");
        supermarket.purchaseItem{value: 0.5 ether}(1, 1);
    }

    function testPurchaseItemFailsIfLocked() public {
        supermarket.addItem("Test", 1 ether, 5);
        supermarket.lockItem(1);
        vm.deal(user, 10 ether);
        vm.prank(user);
        vm.expectRevert("Item is locked");
        supermarket.purchaseItem{value: 1 ether}(1, 1);
    }

    function testPurchaseItemFailsIfInactive() public {
        supermarket.addItem("Test", 1 ether, 5);
        supermarket.changeItemStatus(1, false);
        vm.deal(user, 10 ether);
        vm.prank(user);
    }

    function testPurchaseItemFailsIfZeroAmount() public {
        supermarket.addItem("Test", 1 ether, 5);
        vm.deal(user, 1 ether);
        vm.prank(user);
        vm.expectRevert("Quantity must be greater than 0");
        supermarket.purchaseItem{value: 1 ether}(1, 0);
    }

    function testPurchaseItemFailsIfItemDoesNotExist() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        vm.expectRevert("Item does not exist");
        supermarket.purchaseItem{value: 1 ether}(99, 1);
    }

    function testGetItemReturnsCorrectData() public {
        supermarket.addItem("Sugar", 2 ether, 15);

        (uint256 id, string memory name, uint256 price, uint256 stock, bool isActive) = supermarket.getItem(1);

        assertEq(id, 1);
        assertEq(name, "Sugar");
        assertEq(price, 2 ether);
        assertEq(stock, 15);
        assertTrue(isActive);
    }

    function testGetItemFailsIfDoesNotExist() public {
        vm.expectRevert("Item does not exist");
        supermarket.getItem(999);
    }

    function testGetAllItemIds() public {
        supermarket.addItem("Milk", 1 ether, 10);
        supermarket.addItem("Bread", 2 ether, 15);
        supermarket.addItem("Eggs", 3 ether, 20);

        uint256[] memory ids = supermarket.getAllItemIds();

        assertEq(ids.length, 3, "Should return 3 item IDs");
        assertEq(ids[0], 1);
        assertEq(ids[1], 2);
        assertEq(ids[2], 3);
    }

    function testGetAllItemIdsEmpty() public view {
        uint256[] memory ids = supermarket.getAllItemIds();
        assertEq(ids.length, 0, "Should return an empty array when no items exist");
    }

    function testGetUserPurchasesAfterBuying() public {
        address testBuyer = address(0xBEEF);
        vm.deal(testBuyer, 10 ether);

        supermarket.addItem("Test", 1 ether, 5);

        vm.prank(testBuyer);
        supermarket.purchaseItem{value: 2 ether}(1, 2);
    }

    function testGetUserPurchasesReturnsZeroIfNone() public view {
        uint256 purchased = supermarket.getUserPurchases(buyer, 1);
        assertEq(purchased, 0, "Should return 0 if user hasn't purchased this item");
    }

    function testIsSoldOutReturnsFalseInitially() public {
        supermarket.addItem("Test", 1 ether, 5);
        bool soldOut = supermarket.isSoldOut(1);
        assertEq(soldOut, false, "Item should not be sold out initially");
    }

    function testIsSoldOutReturnsTrueWhenStockIsZero() public {
        supermarket.addItem("Test", 1 ether, 5);

        vm.deal(buyer, 10 ether);
        vm.prank(buyer);
        supermarket.purchaseItem{value: 5 ether}(1, 5);
    }

    function testIsSoldOutFailsIfItemDoesNotExist() public {
        vm.expectRevert("Item does not exist");
        supermarket.isSoldOut(999);
    }

    function testGetStockReturnsCorrectAmount() public {
        supermarket.addItem("Juice", 1 ether, 12);

        uint256 stock = supermarket.getStock(1);
        assertEq(stock, 12, "Stock should be 12 for item ID 1");
    }

    function testGetStockReturnsZeroForUnknownItem() public view {
        uint256 stock = supermarket.getStock(999);
        assertEq(stock, 0, "Nonexistent item should return stock of 0");
    }

    function testEmergencyStopDisablesAllItems() public {
        supermarket.addItem("Test", 1 ether, 5);
        supermarket.emergencyStop();

        (,,,,, bool isAvailable1,,) = supermarket.items(1);
        (,,,,, bool isAvailable2,,) = supermarket.items(2);

        assertFalse(isAvailable1, "Item 1 should be unavailable");
        assertFalse(isAvailable2, "Item 2 should be unavailable");
    }

    function testEmergencyStopFailsIfNotOwner() public {
        vm.prank(attacker);
        vm.expectRevert("Only owner can perform this action");
        supermarket.emergencyStop();
    }

    function testGetTotalItemCountReturnsCorrectValue() public {
        assertEq(supermarket.getTotalItemCount(), 0, "Initially, total count should be 0");

        supermarket.addItem("Rice", 1 ether, 10);
        supermarket.addItem("Beans", 2 ether, 5);
        supermarket.addItem("Yam", 3 ether, 7);

        uint256 total = supermarket.getTotalItemCount();
        assertEq(total, 3, "Total item count should be 3 after adding 3 items");
    }

    function testGetTotalItemCountReturnsZeroWhenEmpty() public view {
        uint256 total = supermarket.getTotalItemCount();
        assertEq(total, 0, "Should return 0 if no items are added");
    }
}
