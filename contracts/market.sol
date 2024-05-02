// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts@4.9.3/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.9.3/access/AccessControl.sol";
import "@openzeppelin/contracts@4.9.3/security/ReentrancyGuard.sol";

/**
 * @title Marketplace for ERC721 tokens
 * @dev Implements buying and renting of NFTs with ERC721 standard. Includes admin controls.
 */
contract Marketplace is ERC721, AccessControl, ReentrancyGuard {
    struct Product {
        address owner;
        string name;
        uint256 price;
        bool isForSale;
        bool isForRent;
        address renter;
        uint256 expirationTime;
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint256 private constant FEE_DENOMINATOR = 100;

    Product[] public products;
    uint256 public referralBonus;
    uint256 public minSalePrice;
    uint256 public minRentPrice;
    uint256 public feePercentage;
    uint256 public defaultExpirationTime;

    mapping(address => uint256) public referrals;

    event ProductAdded(
        uint256 indexed productId,
        address indexed owner,
        string name,
        uint256 price,
        bool isForSale,
        bool isForRent
    );
    event ProductSold(
        uint256 indexed productId,
        address indexed buyer,
        address indexed seller,
        uint256 price
    );
    event ProductRented(
        uint256 indexed productId,
        address indexed renter,
        address indexed owner,
        uint256 price,
        uint256 expirationTime
    );

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        uint256 _referralBonus,
        uint256 _minSalePrice,
        uint256 _minRentPrice,
        uint256 _feePercentage,
        uint256 _defaultExpirationTime
    ) ERC721(name, symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        referralBonus = _referralBonus;
        minSalePrice = _minSalePrice;
        minRentPrice = _minRentPrice;
        feePercentage = _feePercentage;
        defaultExpirationTime = _defaultExpirationTime;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function addProduct(
        string memory _name,
        uint256 _price,
        bool _isForSale,
        bool _isForRent,
        uint256 _expirationTime
    ) external onlyAdmin {
        require(_isForSale || _isForRent, "Product must be for sale or rent.");
        require(_price >= (_isForSale ? minSalePrice : minRentPrice), "Price too low.");

        uint256 newProductId = products.length;
        products.push(Product({
            owner: msg.sender,
            name: _name,
            price: _price,
            isForSale: _isForSale,
            isForRent: _isForRent,
            renter: address(0),
            expirationTime: block.timestamp + (_expirationTime == 0 ? defaultExpirationTime : _expirationTime)
        }));
        _mint(msg.sender, newProductId);

        emit ProductAdded(newProductId, msg.sender, _name, _price, _isForSale, _isForRent);
    }

    function buyProduct(uint256 _productId, address _referrer) external payable nonReentrant {
        Product storage product = products[_productId];
        require(product.isForSale, "Product not for sale.");
        require(msg.value >= product.price, "Insufficient funds.");
        require(product.owner != address(0), "Invalid owner.");

        _handlePayment(product.owner, product.price, _referrer);

        product.owner = msg.sender;
        product.isForSale = false;

        _transfer(product.owner, msg.sender, _productId);

        emit ProductSold(_productId, msg.sender, product.owner, product.price);
    }

    function rentProduct(uint256 _productId, address _referrer) external payable nonReentrant {
        Product storage product = products[_productId];
        require(product.isForRent, "Product not for rent.");
        require(msg.value >= product.price, "Insufficient funds.");
        require(product.renter == address(0), "Product already rented.");

        _handlePayment(product.owner, product.price, _referrer);

        product.renter = msg.sender;
        product.expirationTime = block.timestamp + product.expirationTime;
        product.isForRent = false;

        emit ProductRented(_productId, msg.sender, product.owner, product.price, product.expirationTime);
    }

    function _handlePayment(address recipient, uint256 amount, address referrer) internal {
        uint256 fee = (amount * feePercentage) / FEE_DENOMINATOR;
        uint256 amountToRecipient = amount - fee;

        payable(recipient).transfer(amountToRecipient);
        if (referrer != address(0) && referrer != msg.sender) {
            referrals[referrer]++;
            payable(referrer).transfer(referralBonus);
        }
    }

    function updateReferralBonus(uint256 _newReferralBonus) external onlyAdmin {
        referralBonus = _newReferralBonus;
    }

    function updateMinSalePrice(uint256 _newMinSalePrice) external onlyAdmin {
        minSalePrice = _newMinSalePrice;
    }

    function updateMinRentPrice(uint256 _newMinRentPrice) external onlyAdmin {
        minRentPrice = _newMinRentPrice;
    }

    function updateFeePercentage(uint256 _newFeePercentage) external onlyAdmin {
        feePercentage = _newFeePercentage;
    }

    function withdrawFunds() external onlyAdmin {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
}
