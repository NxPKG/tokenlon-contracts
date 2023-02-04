// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma abicoder v2;

import { AllowanceTarget } from "contracts/AllowanceTarget.sol";
import { SignatureValidator } from "contracts/utils/SignatureValidator.sol";
import { Spender } from "contracts/Spender.sol";
import { TokenCollector } from "contracts/TokenCollector.sol";
import { ITokenCollector } from "contracts/interfaces/ITokenCollector.sol";
import { IUniswapPermit2 } from "contracts/interfaces/IUniswapPermit2.sol";
import { SpenderLibEIP712 } from "contracts/utils/SpenderLibEIP712.sol";
import { MockERC20Permit } from "test/mocks/MockERC20Permit.sol";
import { Addresses } from "test/utils/Addresses.sol";

contract TestTokenCollector is Addresses {
    uint256 userPrivateKey = uint256(1);
    address user = vm.addr(userPrivateKey);

    MockERC20Permit token = new MockERC20Permit("Token", "TKN", 18);

    Spender spender = new Spender(address(this), new address[](0));
    AllowanceTarget allowanceTarget = new AllowanceTarget(address(spender));

    TokenCollector tokenCollector = new TokenCollector(address(spender), UNISWAP_PERMIT2_ADDRESS);

    function setUp() public {
        spender.setAllowanceTarget(address(allowanceTarget));

        address[] memory authorizedList = new address[](1);
        authorizedList[0] = address(tokenCollector);
        spender.authorize(authorizedList);

        token.mint(user, 10000 * 1e18);

        vm.label(address(this), "TestingContract");
        vm.label(address(token), "TKN");
    }

    /* Token */

    function testCollectByTokenApproval() public {
        uint256 amount = 100 * 1e18;

        vm.prank(user);
        token.approve(address(tokenCollector), amount);

        bytes memory data = abi.encode(ITokenCollector.Source.Token, bytes(""));
        tokenCollector.collect(address(token), user, address(this), amount, data);

        uint256 balance = token.balanceOf(address(this));
        assertEq(balance, amount);
    }

    function testCollectByTokenPermit() public {
        uint256 amount = 100 * 1e18;

        uint256 nonce = token.nonces(user);
        uint256 deadline = block.timestamp + 1 days;

        bytes32 structHash = keccak256(abi.encode(token._PERMIT_TYPEHASH(), user, address(tokenCollector), amount, nonce, deadline));
        bytes32 permitHash = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, permitHash);

        bytes memory data = abi.encode(ITokenCollector.Source.Token, abi.encode(user, address(tokenCollector), amount, deadline, v, r, s));
        tokenCollector.collect(address(token), user, address(this), amount, data);

        uint256 balance = token.balanceOf(address(this));
        assertEq(balance, amount);
    }

    /* Spender */

    function testCollectBySpenderApproval() public {
        uint256 amount = 100 * 1e18;

        vm.prank(user);
        token.approve(address(allowanceTarget), amount);

        bytes memory data = abi.encode(ITokenCollector.Source.Spender, bytes(""));
        tokenCollector.collect(address(token), user, address(this), amount, data);

        uint256 balance = token.balanceOf(address(this));
        assertEq(balance, amount);
    }

    function testCollectBySpenderPermit() public {
        uint256 amount = 100 * 1e18;

        vm.prank(user);
        token.approve(address(allowanceTarget), amount);

        SpenderLibEIP712.SpendWithPermit memory permit = SpenderLibEIP712.SpendWithPermit({
            tokenAddr: address(token),
            requester: address(tokenCollector),
            user: user,
            recipient: address(this),
            amount: amount,
            actionHash: bytes32(0x0),
            expiry: uint64(block.timestamp + 1 days)
        });
        bytes32 structHash = SpenderLibEIP712._getSpendWithPermitHash(permit);
        bytes32 permitHash = keccak256(abi.encodePacked("\x19\x01", spender.EIP712_DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, permitHash);
        bytes memory permitSig = abi.encodePacked(r, s, v, uint8(SignatureValidator.SignatureType.EIP712));

        bytes memory data = abi.encode(ITokenCollector.Source.Spender, abi.encode(permit, permitSig));
        tokenCollector.collect(address(token), user, address(this), amount, data);

        uint256 balance = token.balanceOf(address(this));
        assertEq(balance, amount);
    }

    /* Permit2 */

    bytes32 constant TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 constant PERMIT_TRANSFER_FROM_TYPEHASH =
        keccak256(
            "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
        );

    function testCollectByUniswapPermit2() public {
        uint256 amount = 100 * 1e18;

        vm.prank(user);
        token.approve(UNISWAP_PERMIT2_ADDRESS, amount);

        IUniswapPermit2.PermitTransferFrom memory permit = IUniswapPermit2.PermitTransferFrom({
            permitted: IUniswapPermit2.TokenPermissions({ token: address(token), amount: amount }),
            nonce: 1,
            deadline: block.timestamp + 1 days
        });
        IUniswapPermit2.SignatureTransferDetails memory transferDetails = IUniswapPermit2.SignatureTransferDetails({
            to: address(this),
            requestedAmount: amount
        });

        bytes32 structHashTokenPermissions = keccak256(abi.encode(TOKEN_PERMISSIONS_TYPEHASH, permit.permitted));
        bytes32 structHash = keccak256(
            abi.encode(PERMIT_TRANSFER_FROM_TYPEHASH, structHashTokenPermissions, address(tokenCollector), permit.nonce, permit.deadline)
        );
        bytes32 permitHash = keccak256(abi.encodePacked("\x19\x01", IUniswapPermit2(UNISWAP_PERMIT2_ADDRESS).DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, permitHash);
        bytes memory permitSig = abi.encodePacked(r, s, v);

        bytes memory data = abi.encode(ITokenCollector.Source.UniswapPermit2, abi.encode(permit, transferDetails, user, permitSig));
        tokenCollector.collect(address(token), user, address(this), amount, data);

        uint256 balance = token.balanceOf(address(this));
        assertEq(balance, amount);
    }
}
