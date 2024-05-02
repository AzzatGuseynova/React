// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts@4.9.3/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.9.3/access/AccessControl.sol";

/**
 * @title Marketplace for ERC721 tokens
 * @dev Implements buying and renting of NFTs with ERC721 standard
 */
contract Marketplace is ERC721, AccessControl {
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

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return ERC721.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId);
    }


    /**
     * @dev Adds a product to the marketplace
     * @param _name Name of the product
     * @param _price Price of the product
     * @param _isForSale Whether the product is for sale
     * @param _isForRent Whether the product is for rent
     * @param _expirationTime Duration in seconds for which the product is available for rent
     */
    function addProduct(
        string memory _name,
        uint256 _price,
        bool _isForSale,
        bool _isForRent,
        uint256 _expirationTime
    ) external onlyAdmin {
        require(
            _price >= minSalePrice || (_isForRent && _price >= minRentPrice),
            "Price too low."
        );
        require(_isForSale || _isForRent, "Product must be for sale or rent.");
        uint256 newProductId = products.length;
        products.push(
            Product(
                msg.sender,
                _name,
                _price,
                _isForSale,
                _isForRent,
                address(0),
                block.timestamp + (_expirationTime == 0 ? defaultExpirationTime : _expirationTime)
            )
        );
        _mint(msg.sender, newProductId);
        emit ProductAdded(
            newProductId,
            msg.sender,
            _name,
            _price,
            _isForSale,
            _isForRent
        );
    }

    /**
     * @dev Buys a product from the marketplace
     * @param _productId ID of the product
     * @param _referrer Address of the referrer
     */
    function buyProduct(uint256 _productId, address _referrer) external payable {
        Product storage product = products[_productId];
        require(product.isForSale, "Product not for sale.");
        require(msg.value >= product.price, "Insufficient funds.");
        require(product.owner != address(0), "Invalid owner.");

        uint256 fee = (product.price * feePercentage) / 100;
        uint256 amountToSeller = product.price - fee;

        payable(product.owner).transfer(amountToSeller);
        if (_referrer != address(0) && _referrer != msg.sender) {
            referrals[_referrer]++;
            payable(_referrer).transfer(referralBonus);
        }

        product.owner = msg.sender;
        product.isForSale = false;

        _transfer(product.owner, msg.sender, _productId);

        emit ProductSold(_productId, msg.sender, product.owner, product.price);
    }

    /**
     * @dev Rents a product from the marketplace
     * @param _productId ID of the product to rent
     * @param _referrer Address of the referrer
     */
    function rentProduct(uint256 _productId, address _referrer) external payable {
        Product storage product = products[_productId];
        require(product.isForRent, "Product not for rent.");
        require(msg.value >= product.price, "Insufficient funds.");
        require(product.renter == address(0), "Product already rented.");

        uint256 fee = (product.price * feePercentage) / 100;
        uint256 amountToOwner = product.price - fee;

        payable(product.owner).transfer(amountToOwner);
        if (_referrer != address(0) && _referrer != msg.sender) {
            referrals[_referrer]++;
            payable(_referrer).transfer(referralBonus);
        }

        product.renter = msg.sender;
        product.expirationTime = block.timestamp + product.expirationTime;
        product.isForRent = false;

        emit ProductRented(
            _productId,
            msg.sender,
            product.owner,
            product.price,
            product.expirationTime
        );
    }

    /**
     * @dev Allows the admin to update the referral bonus
     * @param _newReferralBonus The new referral bonus amount
     */
    function updateReferralBonus(uint256 _newReferralBonus) external onlyAdmin {
        referralBonus = _newReferralBonus;
    }

    /**
     * @dev Allows the admin to update the minimum sale price
     * @param _newMinSalePrice The new minimum sale price
     */
    function updateMinSalePrice(uint256 _newMinSalePrice) external onlyAdmin {
        minSalePrice = _newMinSalePrice;
    }

    /**
     * @dev Allows the admin to update the minimum rent price
     * @param _newMinRentPrice The new minimum rent price
     */
    function updateMinRentPrice(uint256 _newMinRentPrice) external onlyAdmin {
        minRentPrice = _newMinRentPrice;
    }

    /**
     * @dev Allows the admin to update the fee percentage
     * @param _newFeePercentage The new fee percentage
     */
    function updateFeePercentage(uint256 _newFeePercentage) external onlyAdmin {
        feePercentage = _newFeePercentage;
    }

    /**
     * @dev Allows the admin to withdraw funds from the contract
     */
    function withdrawFunds() external onlyAdmin {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
}
