// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Marketplace is ERC721 {
    struct Product {
        address owner;
        string name;
        uint256 price; 
        bool isForSale;
        bool isForRent;
        address renter;
        uint256 expirationTime; 
    }

    Product[] public products;
    address public admin;
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
        require(msg.sender == admin, "Only admin can call this function.");
        _;
    }

    constructor(
        address _admin,
        uint256 _referralBonus,
        uint256 _minSalePrice,
        uint256 _minRentPrice,
        uint256 _feePercentage,
        uint256 _defaultExpirationTime
    ) ERC721("MarketplaceNFT", "NFT") {
        admin = _admin;
        referralBonus = _referralBonus;
        minSalePrice = _minSalePrice;
        minRentPrice = _minRentPrice;
        feePercentage = _feePercentage;
        defaultExpirationTime = _defaultExpirationTime;
    }

    function addProduct(
        string memory _name,
        uint256 _price,
        bool _isForSale,
        bool _isForRent,
        uint256 _expirationTime
    ) external {
        require(
            _price >= minSalePrice || (_isForRent && _price >= minRentPrice),
            "Price too low."
        );
        uint256 expiration = _expirationTime == 0
            ? block.timestamp + defaultExpirationTime
            : _expirationTime;
        uint256 newProductId = products.length;
        products.push(
            Product(
                msg.sender,
                _name,
                _price,
                _isForSale,
                _isForRent,
                address(0),
                expiration
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

    function buyProduct(uint256 _productId, address _referrer)
        external
        payable
    {
        Product storage product = products[_productId];
        require(product.isForSale, "Product not for sale.");
        require(msg.value >= product.price, "Insufficient funds.");

        if (_referrer != address(0) && _referrer != msg.sender) {
            referrals[_referrer] += 1;
            payable(_referrer).transfer(referralBonus);
        }

        uint256 fee = (product.price * feePercentage) / 100;
        uint256 amountToSeller = product.price - fee;

        payable(product.owner).transfer(amountToSeller);
        emit ProductSold(_productId, msg.sender, product.owner, product.price);
        product.owner = msg.sender;
        product.isForSale = false;
        _transfer(address(this), msg.sender, _productId);
    }

    function rentProduct(uint256 _productId, address _referrer)
        external
        payable
    {
        Product storage product = products[_productId];
        require(product.isForRent, "Product not for rent.");
        require(msg.value >= product.price, "Insufficient funds.");
        require(product.renter == address(0), "Product already rented.");

        if (_referrer != address(0) && _referrer != msg.sender) {
            referrals[_referrer] += 1;
            payable(_referrer).transfer(referralBonus);
        }

        uint256 fee = (product.price * feePercentage) / 100;
        uint256 amountToSeller = product.price - fee;

        payable(product.owner).transfer(amountToSeller);
        emit ProductRented(
            _productId,
            msg.sender,
            product.owner,
            product.price,
            product.expirationTime
        );
        product.renter = msg.sender;
        product.isForRent = false;
    }

    function setReferralBonus(uint256 _referralBonus) external onlyAdmin {
        referralBonus = _referralBonus;
    }

    function setMinSalePrice(uint256 _minSalePrice) external onlyAdmin {
        minSalePrice = _minSalePrice;
    }

    function setMinRentPrice(uint256 _minRentPrice) external onlyAdmin {
        minRentPrice = _minRentPrice;
    }

    function setFeePercentage(uint256 _feePercentage) external onlyAdmin {
        feePercentage = _feePercentage;
    }

    function setDefaultExpirationTime(uint256 _defaultExpirationTime)
        external
        onlyAdmin
    {
        defaultExpirationTime = _defaultExpirationTime;
    }

    function withdrawFunds(uint256 _amount) external onlyAdmin {
        require(
            _amount <= address(this).balance,
            "Insufficient contract balance."
        );
        payable(admin).transfer(_amount);
    }

    function getProductCount() external view returns (uint256) {
        return products.length;
    }
}
