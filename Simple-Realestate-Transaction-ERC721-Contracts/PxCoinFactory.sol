pragma solidity ^0.5.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

/**

    @dev Factory contract that generates ERC721 NFT for a given property ID

 */
contract PxCoinFactory is ERC721 {
    using SafeMath for uint256;

    string public constant name = "PxCoin";
    string public constant symbol = "PxC";

    event CoinGenerated(uint256 _coinId, uint256 _propertyId);

    struct PxCoin {
        uint256 propertyId;
        uint256 valueInEth;
    }

    PxCoin[] public pxCoins;

    /**

        @dev retrieves given coin's value in ether
        @param _coinId a uint identifier associated with a unique PxCoin
        @return _valueInEth returns the given coin's value in ether

     */
    function getPropertyValue(uint256 _coinId)
        public
        view
        returns (uint256 _valueInEth)
    {
        PxCoin memory _currCoin = pxCoins[_coinId];

        _valueInEth = _currCoin.valueInEth;
    }

    /**

        @dev generates an ERC721 token for the given property ID
        @param _propertyId a uint identifier associated with the property
        @param _value the property's value in ether
        @return _coinId - a unique ERC721 token ID generated for the property

     */
    function mint(uint256 _propertyId, uint256 _value)
        public
        payable
        returns (uint256)
    {
        PxCoin memory _newCoin = PxCoin({
            propertyId: _propertyId,
            valueInEth: _value * 1 ether
        });
        uint256 _coinId = pxCoins.push(_newCoin) - 1;

        _mint(msg.sender, _coinId);

        emit CoinGenerated(_coinId, _propertyId);

        return _coinId;
    }
}
