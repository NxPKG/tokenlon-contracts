// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

string constant OFFER_TYPESTRING = "Offer(address taker,address maker,address takerToken,uint256 takerTokenAmount,address makerToken,uint256 makerTokenAmount,uin256 feeFactor,uint256 expiry,uint256 salt)";

bytes32 constant OFFER_DATA_TYPEHASH = 0xf30d11476addc401400b769cb67986b08943cb2e019e1ba9dc0442e80a25664c;
// keccak256(OFFER_TYPESTRING);

struct Offer {
    address taker;
    address payable maker;
    address takerToken;
    uint256 takerTokenAmount;
    address makerToken;
    uint256 makerTokenAmount;
    uint256 feeFactor;
    uint256 expiry;
    uint256 salt;
}

// solhint-disable-next-line func-visibility
function getOfferHash(Offer memory offer) pure returns (bytes32) {
    return
        keccak256(
            abi.encode(
                OFFER_DATA_TYPEHASH,
                offer.taker,
                offer.maker,
                offer.takerToken,
                offer.takerTokenAmount,
                offer.makerToken,
                offer.makerTokenAmount,
                offer.feeFactor,
                offer.expiry,
                offer.salt
            )
        );
}
