// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

interface ITokenCollector {
    enum Source {
        Token,
        UniswapPermit2
    }

    function collect(
        address token,
        address from,
        address to,
        uint256 amount,
        bytes memory data
    ) external;
}
