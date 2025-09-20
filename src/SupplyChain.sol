// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract SupplyChain {
    address public immutable i_owner;
    uint256 public nextProductId = 1;

    constructor() {
        i_owner = msg.sender;
    }

    /* =========================
       Events
       ========================= */
    event ProducerRegistered(address indexed producer, string details);
    event QualityInspectorRegistered(address indexed inspector, string details);
    event DistributorRegistered(address indexed distributor, string details);
    event RetailerRegistered(address indexed retailer, string details);

    event ProductCreated(uint256 indexed productId, address indexed producer);
    event QualityInspectorAssigned(uint256 indexed productId, address indexed inspector);
    event CertificationAdded(uint256 indexed productId, string certification);
    event QualityApproved(uint256 indexed productId, address indexed inspector);
    event Transferred(uint256 indexed productId, address indexed from, address indexed to);

    /* =========================
       Product model
       ========================= */
    struct Product {
        uint256 productId;
        string name;
        string batchId;
        string category;

        // Production Info
        address producer;
        uint256 productionDate;
        uint256 expiryDate;

        // Quality / Certification
        address qualityInspector;
        string[] certifications;
        bool qualityApproved;

        // Supply Chain Journey
        address distributor;
        address retailer;
        address currentOwner;
        address[] ownersHistory;
        uint256[] transferTimestamps;

        // Logistics & Consumer Facing
        string logisticsInfo;
        bool verified;
        string metadataURI;
    }

    Product[] public products;
    mapping(uint256 => Product) public productById;

    /* =========================
       Roles (fast checks + lists)
       ========================= */
    address[] public producersList;
    address[] public qualityInspectorsList;
    address[] public distributorsList;
    address[] public retailersList;

    mapping(address => bool) public isProducerRegistered;
    mapping(address => bool) public isQualityInspectorRegistered;
    mapping(address => bool) public isDistributorRegistered;
    mapping(address => bool) public isRetailerRegistered;

    mapping(address => string) public producerDetailsByAddress;
    mapping(address => string) public qualityInspectorDetailsByAddress;
    mapping(address => string) public distributorDetailsByAddress;
    mapping(address => string) public retailerDetailsByAddress;

    /* =========================
       Modifiers
       ========================= */
    modifier onlyOwner() {
        require(msg.sender == i_owner, "Not owner");
        _;
    }

    modifier onlyProducer() {
        require(isProducerRegistered[msg.sender], "Not a registered producer");
        _;
    }

    modifier onlyQualityInspector(uint256 productId) {
        require(
            productById[productId].qualityInspector == msg.sender,
            "Not assigned quality inspector for this product"
        );
        _;
    }

    modifier onlyDistributor(uint256 productId) {
        require(productById[productId].distributor == msg.sender, "Not distributor for this product");
        _;
    }

    modifier onlyRetailer(uint256 productId) {
        require(productById[productId].retailer == msg.sender, "Not retailer for this product");
        _;
    }

    /* =========================
       Role registration functions
       ========================= */
    function registerProducer(address _producer, string calldata _details) external onlyOwner {
        require(!isProducerRegistered[_producer], "Producer already registered");
        isProducerRegistered[_producer] = true;
        producersList.push(_producer);
        producerDetailsByAddress[_producer] = _details;
        emit ProducerRegistered(_producer, _details);
    }

    function registerQualityInspector(address _inspector, string calldata _details) external onlyOwner {
        require(!isQualityInspectorRegistered[_inspector], "Inspector already registered");
        isQualityInspectorRegistered[_inspector] = true;
        qualityInspectorsList.push(_inspector);
        qualityInspectorDetailsByAddress[_inspector] = _details;
        emit QualityInspectorRegistered(_inspector, _details);
    }

    function registerDistributor(address _distributor, string calldata _details) external onlyOwner {
        require(!isDistributorRegistered[_distributor], "Distributor already registered");
        isDistributorRegistered[_distributor] = true;
        distributorsList.push(_distributor);
        distributorDetailsByAddress[_distributor] = _details;
        emit DistributorRegistered(_distributor, _details);
    }

    function registerRetailer(address _retailer, string calldata _details) external onlyOwner {
        require(!isRetailerRegistered[_retailer], "Retailer already registered");
        isRetailerRegistered[_retailer] = true;
        retailersList.push(_retailer);
        retailerDetailsByAddress[_retailer] = _details;
        emit RetailerRegistered(_retailer, _details);
    }

    /* =========================
       Product creation & management
       ========================= */

    /// @notice Producer creates a product. productId is assigned automatically.
    function createProduct(
        string calldata _name,
        string calldata _batchId,
        string calldata _category,
        uint256 _productionDate,
        string calldata _metadataURI
    ) external onlyProducer returns (uint256) {
        uint256 pid = nextProductId++;
        Product storage p = productById[pid];

        p.productId = pid;
        p.name = _name;
        p.batchId = _batchId;
        p.category = _category;

        p.producer = msg.sender;
        p.productionDate = _productionDate;
        p.expiryDate = 0;

        p.qualityInspector = address(0);
        p.qualityApproved = false;

        p.distributor = address(0);
        p.retailer = address(0);
        p.currentOwner = msg.sender;

        p.logisticsInfo = "";
        p.verified = false;
        p.metadataURI = _metadataURI;

        // dynamic arrays start empty; push initial owner
        p.ownersHistory.push(msg.sender);
        p.transferTimestamps.push(block.timestamp);

        products.push(p);
        emit ProductCreated(pid, msg.sender);
        return pid;
    }

    /// @notice Producer assigns a quality inspector for the product
    function assignQualityInspector(uint256 productId, address inspector) external onlyProducer {
        Product storage p = productById[productId];
        require(p.productId != 0, "Product not found");
        require(p.producer == msg.sender, "Only producer can assign inspector");
        require(isQualityInspectorRegistered[inspector], "Inspector not registered");

        p.qualityInspector = inspector;
        emit QualityInspectorAssigned(productId, inspector);
    }

    /// @notice Called by the assigned quality inspector to add certification
    function addCertification(uint256 productId, string calldata certification) external onlyQualityInspector(productId) {
        Product storage p = productById[productId];
        p.certifications.push(certification);
        emit CertificationAdded(productId, certification);
    }

    /// @notice Called by assigned quality inspector to approve quality
    function approveQuality(uint256 productId,uint256 expiryDate) external onlyQualityInspector(productId) {
        Product storage p = productById[productId];
        p.qualityApproved = true;
         p.expiryDate = expiryDate;
        emit QualityApproved(productId, msg.sender);
    }

    /* =========================
       Supply chain transfers
       ========================= */

    /// @notice Producer assigns a distributor (and transfers ownership to them)
    function assignDistributor(uint256 productId, address distributor) external onlyProducer {
        require(isDistributorRegistered[distributor], "Distributor not registered");
        Product storage p = productById[productId];
        require(p.productId != 0, "Product not found");
        require(p.producer == msg.sender, "Only producer of product can assign distributor");

        address prev = p.currentOwner;
        p.distributor = distributor;
        p.currentOwner = distributor;
        p.ownersHistory.push(distributor);
        p.transferTimestamps.push(block.timestamp);

        emit Transferred(productId, prev, distributor);
    }

    /// @notice Distributor assigns a retailer (transfer)
    function assignRetailer(uint256 productId, address retailer) external onlyDistributor(productId) {
        Product storage p = productById[productId];
        require(p.productId != 0, "Product not found");
        require(p.distributor == msg.sender, "Only distributor for this product");
        require(isRetailerRegistered[retailer], "Retailer not registered");

        address prev = p.currentOwner;
        p.retailer = retailer;
        p.currentOwner = retailer;
        p.ownersHistory.push(retailer);
        p.transferTimestamps.push(block.timestamp);

        emit Transferred(productId, prev, retailer);
    }

    /// @notice Retailer sells to consumer (final transfer). buyer can be any address.
    function sellToConsumer(uint256 productId, address buyer) external onlyRetailer(productId) {
        Product storage p = productById[productId];
        require(p.productId != 0, "Product not found");
        require(p.retailer == msg.sender, "Only retailer for this product");

        address prev = p.currentOwner;
        p.currentOwner = buyer;
        p.ownersHistory.push(buyer);
        p.transferTimestamps.push(block.timestamp);
        p.verified = p.qualityApproved; // example: mark verified if quality approved

        emit Transferred(productId, prev, buyer);
    }

    /* =========================
       Auxiliary / view helpers
       ========================= */

    /// @notice Convenience getter: returns basic product info (avoid returning full struct if large)
    function getBasicProductInfo(uint256 productId)
        external
        view
        returns (
            uint256 id,
            string memory name,
            string memory batchId,
            string memory category,
            address producer,
            address currentOwner,
            bool qualityApproved
        )
    {
        Product storage p = productById[productId];
        require(p.productId != 0, "Product not found");
        return (p.productId, p.name, p.batchId, p.category, p.producer, p.currentOwner, p.qualityApproved);
    }

    /// @notice Return owners history arrays
    function getOwnershipHistory(uint256 productId) external view returns (address[] memory, uint256[] memory) {
        Product storage p = productById[productId];
        require(p.productId != 0, "Product not found");
        return (p.ownersHistory, p.transferTimestamps);
    }

    /// @notice Get full product details including all entity addresses
    function getFullProductDetails(uint256 productId)
        external
        view
        returns (
            uint256 id,
            string memory name,
            string memory batchId,
            string memory category,
            address producer,
            uint256 productionDate,
            uint256 expiryDate,
            address qualityInspector,
            bool qualityApproved,
            address distributor,
            address retailer,
            address currentOwner
        )
    {
        Product storage p = productById[productId];
        require(p.productId != 0, "Product not found");
        return (
            p.productId,
            p.name,
            p.batchId,
            p.category,
            p.producer,
            p.productionDate,
            p.expiryDate,
            p.qualityInspector,
            p.qualityApproved,
            p.distributor,
            p.retailer,
            p.currentOwner
        );
    }

    /// @notice Admin convenience: set expiry date or logistics info
    // function setExpiryAndLogistics(
    //     uint256 productId,
    //     uint256 expiryDate,
    //     string calldata logisticsInfo
    // ) external {
    //     Product storage p = productById[productId];
    //     require(p.productId != 0, "Product not found");
    //     require(p.producer == msg.sender || msg.sender == i_owner, "Only producer or owner");
    //     p.expiryDate = expiryDate;
    //     p.logisticsInfo = logisticsInfo;
    // }
    function getProducerDetails(address producer) external view returns (string memory) {
        require(isProducerRegistered[producer], "Producer not registered");
        return producerDetailsByAddress[producer];
    }
    function getQualityInspectorDetails(address inspector) external view returns (string memory) {
        require(isQualityInspectorRegistered[inspector], "Inspector not registered");
        return qualityInspectorDetailsByAddress[inspector];
    }
    function getDistributorDetails(address distributor) external view returns (string memory) {
        require(isDistributorRegistered[distributor], "Distributor not registered");
        return distributorDetailsByAddress[distributor];
    }
    function getRetailerDetails(address retailer) external view returns (string memory) {
        require(isRetailerRegistered[retailer], "Retailer not registered");
        return retailerDetailsByAddress[retailer];
    }
    function totalProducers() external view returns (uint256) {
        return producersList.length;
    }
    function totalQualityInspectors() external view returns (uint256) {
        return qualityInspectorsList.length;
    }
    function totalDistributors() external view returns (uint256) {
        return distributorsList.length;
    }
    function totalRetailers() external view returns (uint256) {
        return retailersList.length;
    }
    
}