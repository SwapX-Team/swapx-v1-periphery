pragma solidity =0.6.6;

import '@swapx/lib/contracts/libraries/TransferHelper.sol';

import './interfaces/ISwapXV1Migrator.sol';
import './interfaces/V1/ISwapXFactoryV1.sol';
import './interfaces/V1/ISwapXExchangeV1.sol';
import './interfaces/ISwapXV1Router01.sol';
import './interfaces/IERC20.sol';

contract SwapXV1Migrator is ISwapXV1Migrator {
    ISwapXFactoryV1 immutable factoryV1;
    ISwapXV1Router01 immutable router;

    constructor(address _factoryV1, address _router) public {
        factoryV1 = ISwapXFactoryV1(_factoryV1);
        router = ISwapXV1Router01(_router);
    }

    // needs to accept ETH from any v1 exchange and the router. ideally this could be enforced, as in the router,
    // but it's not possible because it requires a call to the v1 factory, which takes too much gas
    receive() external payable {}

    function migrate(address token, uint amountTokenMin, uint amountETHMin, address to, uint deadline)
        external
        override
    {
        ISwapXExchangeV1 exchangeV1 = ISwapXExchangeV1(factoryV1.getExchange(token));
        uint liquidityV1 = exchangeV1.balanceOf(msg.sender);
        require(exchangeV1.transferFrom(msg.sender, address(this), liquidityV1), 'TRANSFER_FROM_FAILED');
        (uint amountETHV1, uint amountTokenV1) = exchangeV1.removeLiquidity(liquidityV1, 1, 1, uint(-1));
        TransferHelper.safeApprove(token, address(router), amountTokenV1);
        (uint amountTokenV2, uint amountETHV2,) = router.addLiquidityETH{value: amountETHV1}(
            token,
            amountTokenV1,
            amountTokenMin,
            amountETHMin,
            to,
            deadline
        );
        if (amountTokenV1 > amountTokenV2) {
            TransferHelper.safeApprove(token, address(router), 0); // be a good blockchain citizen, reset allowance to 0
            TransferHelper.safeTransfer(token, msg.sender, amountTokenV1 - amountTokenV2);
        } else if (amountETHV1 > amountETHV2) {
            // addLiquidityETH guarantees that all of amountETHV1 or amountTokenV1 will be used, hence this else is safe
            TransferHelper.safeTransferETH(msg.sender, amountETHV1 - amountETHV2);
        }
    }
}
