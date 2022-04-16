// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract ERC1155NFTSale is VRFConsumerBase, ERC1155, Ownable, ReentrancyGuard {
    using Strings for uint256;
    using ECDSA for bytes32;

    // Name, Symbol, total token minted count
    string public name; // Not Change
    string public symbol; // Not Chnage
    uint256 public totalMint = 0;

    // Number represet what latest token ID is going on
    uint256 private currentTokenId = 0;

    // Max supply of collection
    uint256 public maxSupply; // Not Change

    // Cost to mint one token in presale
    uint256 public preSaleMintCost; // Change before sale and between

    // Cost to mint one token in pubic sale
    uint256 public publicSaleMintCost; // Change before sale and between

    // Time when presale starts
    uint256 public preSaleStartTime; // can change before presale start

    // Time at which preSale end, calculated preSaleStartTime + preSaleDuration
    uint256 public preSaleEndTime;

    // Default buffer time between presale and public sale, constant 30 seconds
    uint256 public constant defaultPublicSaleBufferDuration = 30;

    // Buffer time to add between presale and public sale i.e 30 + something...
    uint256 public publicSaleBufferDuration; // can change before pre sale sendtart

    // Time at which public sale starts, preSaleStartTime + preSaleDuration + defaultPublicSaleBufferDuration + publicSaleBufferDuration
    uint256 public publicSaleStartTime;

    // Time at which public sale end publicSaleStartTime + publicSaleDuration
    uint256 public publicSaleEndTime;

    // Maximum No of token can be purchased by user in single tx in pre sale
    uint256 public maxTokenPerMintPresale; // can change before pre sale

    // Maximum No of token can be purchased by user in single tx in public sale
    uint256 public maxTokenPerMintPublicSale; // can change before public sale

    // Pre Sale supply limit
    uint256 public limitSupplyInPreSale;

    // Boolean to check if NFTs are revealed
    bool private revealed;
    bool public isPrereveal;

    // Hash map to keep count of token minted by buyer
    mapping(address => uint256) public presalerListPurchases;

    // Whitelist signer address of presale buyers
    address private signerAddress; // Can change before pre sale

    // Boolean to check if randomness is enabled
    bool private isrequestfulfilled;
    uint256 public constant BigPrimeNumber = 9973;

    uint256 private constant fee = 1 * 10**17;
    uint256 private randomNumber;
    bytes32 internal keyHash;
    bytes32 public vrfRequestId;

    modifier preSaleEnded() {
        require(
            block.timestamp > preSaleEndTime,
            "Sorry, the pre-sale is not yet ended"
        );
        _;
    }

    modifier publicSaleStarted() {
        require(
            block.timestamp >= publicSaleStartTime,
            "Sorry, the sale is not yet started"
        );
        _;
    }

    modifier publicSaleNotEnded() {
        require(
            block.timestamp < publicSaleEndTime,
            "Sorry, the sale is ended"
        );
        _;
    }

    modifier publicSaleEnded() {
        require(
            block.timestamp > publicSaleEndTime,
            "Sorry, the sale not yet ended"
        );
        _;
    }

    modifier saleCreated() {
        require(preSaleStartTime != 0, "Sale not created");
        require(publicSaleStartTime != 0, "Sale not created");
        _;
    }

    event URI(string uri);
    event SaleEnded(address account);
    event TokensRevealed(uint256 time);
    event RandomNumberRequested(
        address indexed sender,
        bytes32 indexed vrfRequestId
    );
    event RandomNumberCompleted(
        bytes32 indexed requestId,
        uint256 randomNumber
    );

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _presaleBaseUri,
        uint256 _maxSupply,
        bool _revealed,
        address _vrfCoordinator,
        address _link,
        bytes32 _keyHash
    ) VRFConsumerBase(_vrfCoordinator, _link) ERC1155(_presaleBaseUri) {
        require(
            _maxSupply > 0,
            "Maximum token supply must be greator then zero"
        );

        name = _name;
        symbol = _symbol;
        maxSupply = _maxSupply;
        revealed = _revealed;
        isPrereveal = _revealed;
        keyHash = _keyHash;
    }

    /**
    @notice This function is used to create presale and public sale
    @dev It can only be called by owner
    @param _preSaleMintCost Cost to mint one token in presale 
    @param _publicSaleMintCost Cost to mint one token in pubic sale
    @param _preSaleStartTime Time when presale starts
    @param _preSaleDuration Duration for which presale is live
    @param _publicSaleBufferDuration Buffer time to add between presale and public sale i.e 30 + something...
    @param _publicSaleDuration Duration for which public sales is live
    @param _maxTokenPerMintPresale Maximum No of token can be purchased by user in single tx in pre sale
    @param _maxTokenPerMintPublicSale Maximum No of token can be purchased by user in single tx in public sale
    @param _limitSupplyInPreSale Pre Sale supply limit
    @param _signerAddress Whitelist signer address of presale buyers
    */
    function createSale(
        uint256 _preSaleMintCost,
        uint256 _publicSaleMintCost,
        uint256 _preSaleStartTime,
        uint256 _preSaleDuration,
        uint256 _publicSaleBufferDuration,
        uint256 _publicSaleDuration,
        uint256 _maxTokenPerMintPresale,
        uint256 _maxTokenPerMintPublicSale,
        uint256 _limitSupplyInPreSale,
        address _signerAddress
    ) external onlyOwner {
        require(
            _preSaleMintCost > 0,
            "Token cost must be greater then zero wei"
        );
        require(
            _publicSaleMintCost > 0,
            "Token cost must be greater then zero wei"
        );
        require(
            block.timestamp <= _preSaleStartTime,
            "Presale start time must be greater then current time"
        );
        require(
            _preSaleDuration > 0,
            "Presale duration must be greater then zero"
        );
        require(
            _publicSaleDuration > 0,
            "Public sale duration must be greater then zero"
        );
        require(
            _maxTokenPerMintPresale > 0,
            "Maximum token that can be minted by buyer per mint in presale must be greater then zero"
        );
        require(
            _maxTokenPerMintPublicSale > 0,
            "Maximum token that can be minted by buyer per mint in public sale must be greater then zero"
        );
        require(
            _limitSupplyInPreSale > 0,
            "Limit supply in pre sale must be greater then zero"
        );
        require(
            _limitSupplyInPreSale <= maxSupply,
            "Limit supply in pre sale must be less then or equal to maximum supply"
        );
        require(preSaleStartTime == 0, "Sale already created");
        require(publicSaleStartTime == 0, "Sale already created");
        require(
            LINK.balanceOf(address(this)) >= fee,
            "Not enough LINK tokens available"
        );

        require(isrequestfulfilled, "Please request random number first");

        preSaleMintCost = _preSaleMintCost;
        publicSaleMintCost = _publicSaleMintCost;
        preSaleStartTime = _preSaleStartTime;
        preSaleEndTime = _preSaleStartTime + _preSaleDuration;
        publicSaleBufferDuration = _publicSaleBufferDuration;
        publicSaleStartTime =
            _preSaleStartTime +
            _preSaleDuration +
            defaultPublicSaleBufferDuration +
            _publicSaleBufferDuration;
        publicSaleEndTime = publicSaleStartTime + _publicSaleDuration;
        maxTokenPerMintPresale = _maxTokenPerMintPresale;
        maxTokenPerMintPublicSale = _maxTokenPerMintPublicSale;
        limitSupplyInPreSale = _limitSupplyInPreSale;
        signerAddress = _signerAddress;
    }

    /**
    @notice This function is used to buy and mint nft in presale
    @dev Random token id is generated for assigned to buyer
    @param tokenSignQuantity The token quantity that whitelisted buyer can mint 
    @param tokenQuantity The token quantity that whitelisted buyer wants to mint
    @param signature The signature sent by the buyer
    */
    function preSalebuy(
        uint256 tokenSignQuantity,
        uint256 tokenQuantity,
        bytes memory signature
    ) external payable nonReentrant saleCreated {
        bytes32 hash = hashMessage(
            msg.sender,
            block.chainid,
            tokenSignQuantity
        );
        require(
            tokenQuantity > 0 && tokenSignQuantity > 0,
            "Token quantity to mint must be greter then zero"
        );
        require(
            block.timestamp >= preSaleStartTime,
            "Sorry, the pre-sale is not yet started"
        );
        require(
            block.timestamp <= preSaleEndTime,
            "Sorry, the pre-sale is ended"
        );
        require(
            matchAddressSigner(hash, signature),
            "Sorry, you are not a whitelisted user"
        );
        require(
            tokenQuantity <= maxTokenPerMintPresale,
            "Limit exceed to purchase in single mint"
        );
        require(
            (totalMint + tokenQuantity) <= limitSupplyInPreSale,
            "Sorry, can't be purchased as exceed limitSupplyInPreSale supply."
        );
        require(
            (preSaleMintCost * tokenQuantity) <= msg.value,
            "You need to pay the minimum token price."
        );
        require(msg.sender != address(0), "ERC1155: mint to the zero address");
        require(
            presalerListPurchases[msg.sender] + tokenQuantity <=
                tokenSignQuantity,
            "Sorry,can't be purchased as exceed maximum allowed limit"
        );

        for (uint256 i = 0; i < tokenQuantity; i = unchecked_inc(i)) {
            _incrementTokenId();
            _mint(msg.sender, currentTokenId, 1, "0x");
            presalerListPurchases[msg.sender]++;
            totalMint += uint256(1);
        }
    }

    /**
    @notice This function is used to buy and mint nft in public sale
    @param tokenQuantity The token quantity that buyer wants to mint
    */
    function mint(uint256 tokenQuantity)
        external
        payable
        nonReentrant
        saleCreated
        publicSaleNotEnded
        publicSaleStarted
        preSaleEnded
    {
        require(
            tokenQuantity > 0,
            "Token quantity to mint must be greter then zero"
        );
        require(
            tokenQuantity <= maxTokenPerMintPublicSale,
            "Limit exceed to purchase in single mint"
        );
        require(
            (totalMint + tokenQuantity) <= maxSupply,
            "Sorry, can't be purchased as exceed max supply."
        );
        require(
            (publicSaleMintCost * tokenQuantity) <= msg.value,
            "You need to pay the minimum token price."
        );
        require(msg.sender != address(0), "ERC1155: mint to the zero address");

        for (uint256 i = 0; i < tokenQuantity; i++) {
            _incrementTokenId();
            _mint(msg.sender, currentTokenId, 1, "0x");
            totalMint += uint256(1);
        }
    }

    /**
    @notice This function is used to reveal the token can only be called by owner
    @dev TokensRevealed and URI event is emitted
    */
    function revealTokens(string memory _uri)
        external
        onlyOwner
        publicSaleEnded
    {
        require(!revealed, "Already revealed");

        revealed = true;
        _setURI(_uri);
        emit TokensRevealed(block.timestamp);
        emit URI(_uri);
    }

    /**
    @notice This function is used to request random number form chainlink oracle
    @dev Make sure there is link token available for fees
    @return vrfRequestId chianlink request id
    @return lockBlock block number when the random number is generated
    */
    function requestRandomNumber()
        external
        onlyOwner
        returns (bytes32, uint32)
    {
        require(!isrequestfulfilled, "Already obtained the random number");
        require(
            LINK.balanceOf(address(this)) >= fee,
            "Not enough LINK tokens available"
        );

        uint32 lockBlock = uint32(block.number);
        vrfRequestId = requestRandomness(keyHash, fee);
        emit RandomNumberRequested(msg.sender, vrfRequestId);
        return (vrfRequestId, lockBlock);
    }

    /**
    @notice This function is used to withdraw ether from contract 
    */
    function withdrawEth(uint256 _amount) external onlyOwner nonReentrant {
        require(_amount > 0, "Amount should be greater then zero");
        require(
            address(this).balance >= _amount,
            "Not enough eth balance to withdraw"
        );

        payable(msg.sender).transfer(_amount);
    }

    /**
    @notice This function is used to withdraw Link token from contract 
    */
    function withdrawLink(uint256 _amount) external onlyOwner nonReentrant {
        require(_amount > 0, "Amount should be greater then zero");
        require(
            LINK.balanceOf(address(this)) >= _amount,
            "Not enough LINK tokens available"
        );

        LINK.transfer(msg.sender, _amount);
    }

    // ============================ Getter Functions ============================

    /**
    @notice This function is used to give purchase count of the buyer in presale
    @param addr The Buyer address
    @return uint256 The pre sale purchase count of the buyer
    */
    function presalePurchasedCount(address addr)
        external
        view
        returns (uint256)
    {
        return presalerListPurchases[addr];
    }

    /**
    @notice This function is used to check if pre sale is started
    @return bool Return true if presale is started or not
    */
    function isPreSaleLive() external view returns (bool) {
        return (block.timestamp >= preSaleStartTime &&
            block.timestamp <= preSaleEndTime);
    }

    /**
    @notice This function is used to check if public sale is started
    @return bool Return true if public is started or not
    */
    function isPublicSaleLive() external view returns (bool) {
        return (block.timestamp >= publicSaleStartTime &&
            block.timestamp <= publicSaleEndTime);
    }

    /**
    @notice This function is used to get random asset id
    @return assetID Random assetID
    */
    function getAssetId(uint256 _tokenID) external view returns (uint256) {
        require(_tokenID > 0 && _tokenID <= maxSupply, "Invalid token Id");
        require(
            isrequestfulfilled,
            "Please wait for random number to be assigned"
        );
        require(revealed, "Please reveal the token first");
        uint256 assetID;
        if (isPrereveal) {
            // require(totalMint <= maxSupply, "All Values assigned");
            // uint256 maxIndex = maxSupply - totalMint;
            // uint256 random = uint256(
            //     keccak256(
            //         abi.encodePacked(
            //             msg.sender,
            //             block.coinbase,
            //             block.difficulty,
            //             block.gaslimit,
            //             block.timestamp
            //         )
            //     )
            // ) % maxIndex;
            // uint256 value = 0;
            // value = tokenMatrix[random] == 0 ? random : tokenMatrix[random];
            // tokenMatrix[random] = tokenMatrix[maxIndex - 1] == 0
            //     ? maxIndex - 1
            //     : tokenMatrix[maxIndex - 1];
            // if (mintedToken[value] == 0) {
            //     mintedToken[value] = 1;
            // } else {
            //     revert("Try again");
            // }
            // return value;
        } else {
            assetID =
                BigPrimeNumber *
                _tokenID +
                (randomNumber % BigPrimeNumber);
            assetID = assetID % totalMint;
            if (assetID == 0) assetID = totalMint;
        }
        return assetID;
    }

    /**
    @notice This function is used to get random number
    @return randomNumber Random number geerated by chainlink
    */
    function getRandomNumber() external view returns (uint256) {
        require(
            isrequestfulfilled,
            "Please wait for random number to be assigned"
        );

        return randomNumber;
    }

    /**
    @notice This function is used to get contract ether balance
    @return balance Ether Balance of the contract
    */
    function getBalanceEther() external view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    /**
    @notice This function is used to get contract Link token balance
    @return balance Link token Balance of the contract
    */
    function getBalanceLink() external view onlyOwner returns (uint256) {
        return LINK.balanceOf(address(this));
    }

    /**
    @notice This function is used to get Link address
    @return address Link address
    */
    function getLinkAddress() external view returns (address) {
        return address(LINK);
    }

    // ============================ Utility Functions ============================

    /**
    @dev This function is used to generate hash message
    @param sender The address of the recipient
    @param chainId The ChainID of the network
    @param tokenQuantity The quantity of the token
    @return hash generated by the function
    */
    function hashMessage(
        address sender,
        uint256 chainId,
        uint256 tokenQuantity
    ) private pure returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(sender, chainId, tokenQuantity))
            )
        );
        return hash;
    }

    /**
    @dev This function is used to verify the whitelisted byer using signature
    @param hash The hash message generated by the function hashMessage
    @param signature The signature send by the buyer
    @return boolean value true if the signature is verified else false
    */
    function matchAddressSigner(bytes32 hash, bytes memory signature)
        private
        view
        returns (bool)
    {
        return signerAddress == hash.recover(signature);
    }

    /**
    @dev This function is used to inrement without checking the overflow condition - save gas
    @param i increment it
    @return uint256 inremented value
    */
    function unchecked_inc(uint256 i) internal pure returns (uint256) {
        unchecked {
            return i + 1;
        }
    }

    /**
    @dev Callback function for chainlink oracle and store the random number
    */
    function fulfillRandomness(bytes32 _requestId, uint256 _randomness)
        internal
        override
    {
        randomNumber = _randomness;
        isrequestfulfilled = true;
        emit RandomNumberCompleted(_requestId, _randomness);
    }

    /**
    @dev Fuctions to increment token id
    */
    function _incrementTokenId() private {
        require(currentTokenId < maxSupply, "token Id limit reached");
        currentTokenId++;
    }
}
