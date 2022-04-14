// contracts/Box.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;


import "./Jack.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";


contract Box is Initializable, ERC1155Upgradeable, ERC1155BurnableUpgradeable, OwnableUpgradeable{

     // immutable variable
    uint256 public constant MAX_SUPPLY = 7777;
    uint256 public constant MAX_PUBLIC_MINT = 10;
    uint256 public constant MAX_WHITELIST_MINT = 3;
    uint256 public constant PUBLIC_SALE_PRICE = .009 ether;
    uint256 public constant WHITELIST_SALE_PRICE = .002 ether;
    
    // Box Token ID to mint
    uint16 internal constant TOKEN_ID = 1;
    
    // mutable variable
    bool public isRevealed;
    bool public publicSale;
    uint256 private mintCount;
    bool public whiteListSale;
    bytes32 private merkleRoot;
    address private jack_address;
    
    
    // mappings
    mapping(address => uint256) private totalBurn;
    mapping(address => uint256) private totalPublicMint;
    mapping(address => uint256) private totalWhitelistMint;

    
    function initialize() external initializer{
        __ERC1155_init("");
        __Ownable_init();
        __ERC1155Burnable_init();
    }


    modifier callerIsUser() {
        require(tx.origin == msg.sender, "Box :: Cannot be called by a contract");
        _;
    }

    function mint(uint256 _quantity) external payable callerIsUser{
        require(publicSale, "Box :: Not Yet Active.");
        require( (mintCount + _quantity) <= MAX_SUPPLY, "Box :: Beyond Max Supply");
        require( (totalPublicMint[msg.sender] +_quantity) <= MAX_PUBLIC_MINT, "Box :: Already minted 10 times!");
        require( (msg.value) >= (PUBLIC_SALE_PRICE * _quantity), "Box :: Payment is below the price ");
        
        mintCount += _quantity;
        totalPublicMint[msg.sender] += _quantity;
        ERC1155Upgradeable._mint(msg.sender, TOKEN_ID, _quantity, "");
    }

    function whitelistMint(bytes32[] memory _merkleProof, uint256 _quantity) external payable callerIsUser{
        require(whiteListSale, "Box :: Minting is on Pause");
        require( (mintCount + _quantity) <= MAX_SUPPLY, "Box :: Cannot mint beyond max supply");
        require( (totalWhitelistMint[msg.sender] + _quantity)  <= MAX_WHITELIST_MINT, "Box :: Cannot mint beyond whitelist max mint!");
        require( (msg.value) >= (WHITELIST_SALE_PRICE * _quantity), "Box :: Payment is below the price");
        bytes32 sender = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProofUpgradeable.verify(_merkleProof, merkleRoot, sender), "Box :: You are not whitelisted");

        mintCount += _quantity;
        totalWhitelistMint[msg.sender] += _quantity;
        ERC1155Upgradeable._mint(msg.sender, TOKEN_ID, _quantity, "");
    }  

    function mintJack(uint256 _quantity) internal {
        Jack jack = Jack(jack_address);
        jack.mint(msg.sender,_quantity);
    }

    function setJackAddress(address _jack_address) external onlyOwner{
        jack_address = _jack_address;
    }

    function getJackAddress() external view returns (address){
        return jack_address;
    }

    function burn(address from, uint256 _quantity) public virtual  callerIsUser{
        require(_quantity > 0 , "Increase quantity");
        require(from == _msgSender() || isApprovedForAll(from, _msgSender()), "ERC1155: caller is not owner nor approved");
        ERC1155Upgradeable._burn(from, TOKEN_ID, _quantity);
        totalBurn[msg.sender] += _quantity;
        mintJack(_quantity);
    }
   
    function setCollectionURI(string calldata uri) external  onlyOwner {
        ERC1155Upgradeable._setURI(uri);
    }
   
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner{
        merkleRoot = _merkleRoot;
    }

    function getMerkleRoot() external view returns (bytes32){
        return merkleRoot;
    }

    function toggleWhiteListSale() external onlyOwner{
        whiteListSale = !whiteListSale;
    }

    function toggleReveal() external onlyOwner{
        isRevealed = !isRevealed;
    }

    function togglePublicSale() external onlyOwner{
        publicSale = !publicSale;
    }

    function ownerHolds(address owner) external view returns (uint256) {
        return ERC1155Upgradeable.balanceOf(owner, TOKEN_ID);
    }

    function tokenWhitelistMintBy(address owner) external view  returns (uint256) {
        return totalWhitelistMint[owner] ;
    }

    function tokenPublicMintBy(address owner) external view  returns (uint256) {
        return totalPublicMint[owner] ;
    }

    function tokenBurnBy(address owner) external view  returns (uint256) {
        return  totalBurn[owner] ;
    }

    function withdraw() external onlyOwner{
        payable(msg.sender).transfer(address(this).balance);
    }

    function totalSupply() external view returns (uint256) {
        return mintCount;
    }

    function version() external pure returns (string memory) {
        return "1.0.0";
    }
    
}