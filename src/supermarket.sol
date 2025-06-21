// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// contract Supermarket
contract Supermarket {
    address public owner;

    // Struct to represent an item in the supermarket
    struct Item {
        uint256 id;
        string name;
        uint256 price;
        uint256 stock;
        uint256 quantity;
        bool isAvailable;
        bool locked;
        bool exists;
    }

    // State variables
    uint256[] public itemIds;
    uint256 public nextItemId;
    mapping(uint256 => Item) public items;
    mapping(address => mapping(uint256 => uint256)) public userPurchases;

    // Events
    event ItemAdded(uint256 indexed itemId, string name, uint256 price, uint256 quantity, uint256 stock);
    event ItemLocked(uint256 indexed itemId);
    event ItemUnlocked(uint256 indexed itemId);
    event ItemRestocked(uint256 indexed itemId, uint256 newStock);
    event ItemStatusChanged(uint256 indexed itemId, bool isActive);
    event ItemPriceUpdated(uint256 indexed itemId, uint256 newPrice);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ItemPurchased(
        uint256 indexed itemId, address indexed buyer, uint256 amount, uint256 quantity, uint256 totalCost
    );

    // Constructor to initialize the contract
    constructor() {
        owner = msg.sender;
        nextItemId = 1;
    }

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    // Modifier to check if an item exists
    modifier itemExists(uint256 _itemId) {
        require(items[_itemId].exists, "Item does not exist");
        _;
    }

    // Modifier to check if an item is available for purchase
    modifier itemActive(uint256 _itemId) {
        require(items[_itemId].isAvailable, "Item is not available for purchase");
        _;
    }

    // Modifier to check if the quantity is valid (greater than 0)
    modifier validQuantity(uint256 _quantity) {
        require(_quantity > 0, "Quantity must be greater than 0");
        _;
    }

    // Function to add a new item to the supermarket
    function addItem(string memory _name, uint256 _price, uint256 _quantity) external onlyOwner {
        require(_price > 0, "Price must be greater than 0");
        require(_quantity > 0, "Quantity must be greater than 0");

        items[nextItemId] = Item({
            id: nextItemId,
            name: _name,
            price: _price,
            stock: _quantity,
            quantity: _quantity,
            isAvailable: true,
            locked: false,
            exists: true
        });

        itemIds.push(nextItemId);
        emit ItemAdded(nextItemId, _name, _price, _quantity, _quantity);

        nextItemId++;
    }

    // Function to buy an item
    function buyItem(uint256 _id, uint256 _quantity) public payable {
        Item storage item = items[_id];
        require(item.isAvailable, "Item not available");
        require(item.stock >= _quantity, "Not enough stock");
        require(msg.value >= item.price * _quantity, "Not enough payment");

        item.stock -= _quantity;
        emit ItemPurchased(_id, msg.sender, msg.value, _quantity, item.price * _quantity);
    }

    // Function to lock or unlock an item
    function lockItem(uint256 itemId) external onlyOwner itemExists(itemId) {
        items[itemId].locked = true;
        emit ItemLocked(itemId);
    }

    // Function to unlock an item
    function unlockItem(uint256 itemId) external onlyOwner itemExists(itemId) {
        items[itemId].locked = false;
        emit ItemUnlocked(itemId);
    }

    // Function to restock an item
    function restockItem(uint256 itemId, uint256 addedStock) external onlyOwner itemExists(itemId) {
        items[itemId].quantity += addedStock;
        emit ItemRestocked(itemId, items[itemId].quantity);
    }

    // Function to change the availability status of an item
    function changeItemStatus(uint256 itemId, bool isActive) external onlyOwner itemExists(itemId) {
        items[itemId].locked = !isActive; // isActive true => unlocked, false => locked
        items[itemId].isAvailable = isActive;
        emit ItemStatusChanged(itemId, isActive);
    }

    // Function to get the details of an item
    function getAvailableItems()
        external
        view
        returns (uint256[] memory ids, string[] memory names, uint256[] memory prices, uint256[] memory stocks)
    {
        uint256 availableCount = 0;

        // Count available items
        for (uint256 i = 0; i < itemIds.length; i++) {
            uint256 itemId = itemIds[i];
            if (items[itemId].isAvailable && items[itemId].stock > 0) {
                availableCount++;
            }
        }

        // Initialize arrays
        ids = new uint256[](availableCount);
        names = new string[](availableCount);
        prices = new uint256[](availableCount);
        stocks = new uint256[](availableCount);

        // Populate arrays
        uint256 index = 0;
        for (uint256 i = 0; i < itemIds.length; i++) {
            uint256 itemId = itemIds[i];
            Item memory item = items[itemId];
            if (item.isAvailable && item.stock > 0) {
                ids[index] = item.id;
                names[index] = item.name;
                prices[index] = item.price;
                stocks[index] = item.stock;
                index++;
            }
        }
    }

    // Function to update the price of an item
    function updateItemPrice(uint256 itemId, uint256 newPrice) external onlyOwner itemExists(itemId) {
        // require(newPrice > 0, "Price must be greater than zero");
        items[itemId].price = newPrice;
        emit ItemPriceUpdated(itemId, newPrice);
    }

    // Function to transfer ownership of the contract
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");

        address previousOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(previousOwner, newOwner);
    }

    // Function to purchase an item
    function purchaseItem(uint256 itemId, uint256 amount)
        external
        payable
        itemExists(itemId)
        itemActive(itemId)
        validQuantity(amount)
    {
        Item storage item = items[itemId];
        require(!item.locked, "Item is locked");
        require(item.quantity >= amount, "Not enough stock available");

        uint256 totalCost = item.price * amount;

        require(msg.value >= totalCost, "Insufficient payment");

        item.quantity -= amount;

        // Optionally, refund excess ETH sent
        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }

        emit ItemPurchased(itemId, msg.sender, amount, item.quantity, totalCost);
    }

    // Function to get the details of a specific item
    function getItem(uint256 _itemId)
        external
        view
        itemExists(_itemId)
        returns (uint256 id, string memory name, uint256 price, uint256 stock, bool isActive)
    {
        Item memory item = items[_itemId];
        return (item.id, item.name, item.price, item.stock, item.isAvailable);
    }

    // Function to get all item IDs
    function getAllItemIds() external view returns (uint256[] memory) {
        return itemIds;
    }

    // Function to get the number of items in the supermarket
    function getUserPurchases(address _user, uint256 _itemId) external view returns (uint256) {
        return userPurchases[_user][_itemId];
    }

    // Function to check if an item is sold out
    function isSoldOut(uint256 _itemId) external view itemExists(_itemId) returns (bool) {
        return items[_itemId].stock == 0;
    }

    // Add this function if it does not exist:
    function getStock(uint256 itemId) public view returns (uint256) {
        // Replace with your actual storage logic
        return items[itemId].stock;
    }

    // Function to emergency stop the supermarket
    function emergencyStop() external onlyOwner {
        for (uint256 i = 0; i < itemIds.length; i++) {
            items[itemIds[i]].isAvailable = false;
        }
    }

    // Function to get the total number of items in the supermarket
    function getTotalItemCount() external view returns (uint256) {
        return itemIds.length;
    }
}
