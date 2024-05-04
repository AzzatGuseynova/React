// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract ERC721 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function balanceOf(address owner) public view returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    function approve(address to, uint256 tokenId) public {
        address owner = ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");
        require(msg.sender == owner || isApprovedForAll(owner, msg.sender), "ERC721: approve caller is not owner nor approved for all");
        
        _approve(to, tokenId);
    }

    function _approve(address to, uint256 tokenId) internal {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function setApprovalForAll(address operator, bool approved) public {
        require(operator != msg.sender, "ERC721: approve to caller");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function _mint(address to, uint256 tokenId) internal {
        require(to != address(0), "ERC721: mint to the zero address");
        require(_owners[tokenId] == address(0), "ERC721: token already minted");

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        require(ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }
}


contract AccessControl {
    mapping(bytes32 => mapping(address => bool)) private _roles;

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    modifier onlyRole(bytes32 role) {
        require(_roles[role][msg.sender], "AccessControl: sender does not have role");
        _;
    }

    function grantRole(bytes32 role, address account) public onlyRole(role) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public onlyRole(role) {
        _revokeRole(role, account);
    }

    function _grantRole(bytes32 role, address account) internal {
        if (!_roles[role][account]) {
            _roles[role][account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    function _revokeRole(bytes32 role, address account) internal {
        if (_roles[role][account]) {
            _roles[role][account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }
}

contract ReentrancyGuard {
    bool private _reentrantLock = false;

    modifier nonReentrant() {
        require(!_reentrantLock, "ReentrancyGuard: reentrant call");
        _reentrantLock = true;
        _;
        _reentrantLock = false;
    }
}

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

    event ProductAdded(uint256 indexed productId, address indexed owner, string name, uint256 price, bool isForSale, bool isForRent);
    event ProductSold(uint256 indexed productId, address indexed buyer, address indexed seller, uint256 price);
    event ProductRented(uint256 indexed productId, address indexed renter, address indexed owner, uint256 price, uint256 expirationTime);

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function addProduct(string memory name, uint256 price, bool isForSale, bool isForRent, uint256 expirationTime) public onlyRole(ADMIN_ROLE) {
        products.push(Product({
            owner: msg.sender,
            name: name,
            price: price,
            isForSale: isForSale,
            isForRent: isForRent,
            renter: address(0),
            expirationTime: block.timestamp + expirationTime
        }));
        uint256 productId = products.length - 1;
        _mint(msg.sender, productId);
        emit ProductAdded(productId, msg.sender, name, price, isForSale, isForRent);
    }

    /**
     * @notice Buys a product from the marketplace, transferring ownership to the buyer
     * @dev Ensures the product is for sale and the sent value covers the price. Handles payments.
     * @param _productId ID of the product to buy
     * @param _referrer Address of the referrer (if any) to receive a bonus
     */
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


    /**
     * @notice Rents a product, assigning temporary possession to the renter
     * @dev Ensures the product is for rent and the sent value covers the rent price. Resets rent status post transaction.
     * @param _productId ID of the product to rent
     * @param _referrer Address of the referrer (if any) to receive a bonus
     */
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

    /**
     * @dev Internal function to handle payment distribution and referral bonuses.
     * @param recipient The address of the product seller.
     * @param amount The transaction amount.
     * @param referrer The address of the referrer, if any.
     */
    function _handlePayment(address recipient, uint256 amount, address referrer) internal {
        uint256 fee = (amount * feePercentage) / FEE_DENOMINATOR;
        uint256 amountToRecipient = amount - fee;

        payable(recipient).transfer(amountToRecipient);
        if (referrer != address(0) && referrer != msg.sender) {
            referrals[referrer]++;
            payable(referrer).transfer(referralBonus);
        }
    }

    function updateReferralBonus(uint256 _newReferralBonus) external onlyRole(ADMIN_ROLE) {
    referralBonus = _newReferralBonus;
    } 

    function updateMinSalePrice(uint256 _newMinSalePrice) external onlyRole(ADMIN_ROLE) {
        minSalePrice = _newMinSalePrice;
    }

    function updateMinRentPrice(uint256 _newMinRentPrice) external onlyRole(ADMIN_ROLE) {
        minRentPrice = _newMinRentPrice;
    }

    function updateFeePercentage(uint256 _newFeePercentage) external onlyRole(ADMIN_ROLE) {
        feePercentage = _newFeePercentage;
    }

    function withdrawFunds() external onlyRole(ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
}