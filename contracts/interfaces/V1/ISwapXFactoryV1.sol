pragma solidity >=0.5.0;

interface ISwapXFactoryV1 {
    function getExchange(address) external view returns (address);
}
