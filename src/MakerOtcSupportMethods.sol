pragma solidity ^0.4.23;
// pragma experimental ABIEncoderV2;

import "ds-math/math.sol";

contract OtcInterface {
    struct OfferInfo {
        uint              pay_amt;
        address           pay_gem;
        uint              buy_amt;
        address           buy_gem;
        address           owner;
        uint64            timestamp;
    }
    mapping (uint => OfferInfo) public offers;
    function getBestOffer(address, address) public view returns (uint);
    function getWorseOffer(uint) public view returns (uint);
}

contract MakerOtcSupportMethods is DSMath {
    function getOffers(OtcInterface otc, address payToken, address buyToken) public view returns (uint[100] offers) {
        offers = getOffers(otc, otc.getBestOffer(payToken, buyToken));
    }

    function getOffers(OtcInterface otc, uint lastOfferId) public view returns (uint[100] offers) {
        uint i = 0;
        while (i < 100) {
            if (lastOfferId != 0) {
                offers[i] = lastOfferId;
                // var (a, b, c, d, e, f) = otc.offers(lastOfferId);
                // offers[i] = OtcInterface.OfferInfo(a, b, c, d, e, f);
                lastOfferId = otc.getWorseOffer(lastOfferId);
            } else {
                offers[i] = 0;
                // offers[i] = OtcInterface.OfferInfo(0, address(0), 0, address(0), address(0), 0);
            }
            i ++;
        }
    }

    function getOffersAmountToSellAll(OtcInterface otc, address payToken, uint payAmt, address buyToken) public view returns (uint ordersToTake, bool takesPartialOrder) {
        uint offerId = otc.getBestOffer(buyToken, payToken);                        // Get best offer for the token pair
        ordersToTake = 0;
        uint payAmt2 = payAmt;
        uint orderBuyAmt = 0;
        (,,orderBuyAmt,,,) = otc.offers(offerId);
        while (payAmt2 > orderBuyAmt) {
            ordersToTake ++;                                                        // New order taken
            payAmt2 = sub(payAmt2, orderBuyAmt);                                    // Decrease amount to pay
            if (payAmt2 > 0) {                                                      // If we still need more offers
                offerId = otc.getWorseOffer(offerId);                               // We look for the next best offer
                require(offerId != 0);                                              // Fails if there are not enough offers to complete
                (,,orderBuyAmt,,,) = otc.offers(offerId);
            }
            
        }
        ordersToTake = payAmt2 == orderBuyAmt ? ordersToTake + 1 : ordersToTake;    // If the remaining amount is equal than the latest order, then it will also be taken completely
        takesPartialOrder = payAmt2 < orderBuyAmt;                                  // If the remaining amount is lower than the latest order, then it will take a partial order
    }

    function getOffersAmountToBuyAll(OtcInterface otc, address buyToken, uint buyAmt, address payToken) public view returns (uint ordersToTake, bool takesPartialOrder) {
        uint offerId = otc.getBestOffer(buyToken, payToken);                        // Get best offer for the token pair
        ordersToTake = 0;
        uint buyAmt2 = buyAmt;
        uint orderPayAmt = 0;
        (orderPayAmt,,,,,) = otc.offers(offerId);
        while (buyAmt2 > orderPayAmt) {
            ordersToTake ++;                                                        // New order taken
            buyAmt2 = sub(buyAmt2, orderPayAmt);                                    // Decrease amount to buy
            if (buyAmt2 > 0) {                                                      // If we still need more offers
                offerId = otc.getWorseOffer(offerId);                               // We look for the next best offer
                require(offerId != 0);                                              // Fails if there are not enough offers to complete
                (orderPayAmt,,,,,) = otc.offers(offerId);
            }
        }
        ordersToTake = buyAmt2 == orderPayAmt ? ordersToTake + 1 : ordersToTake;    // If the remaining amount is equal than the latest order, then it will also be taken completely
        takesPartialOrder = buyAmt2 < orderPayAmt;                                  // If the remaining amount is lower than the latest order, then it will take a partial order
    }
}
