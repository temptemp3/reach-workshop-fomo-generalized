'reach 0.1';
'use strict';

// WORKSHOP
// 1. Problem Analysis
// What funds change ownership during the application?
// Buyers continually purchase tickets adding funds to the balance during execution 
// until the last N Buyers, and potentially the Funder, split the blance. 
// A Buyer may purchase a single ticket.
// The price of tickets may increase as more tickets are sold. 
// If less than N buyers purchase a ticket, then a portion of the balance is given to the Funder.
// 2. Data Definition
// Same as Workshop: Fomo (https://docs.reach.sh/workshop-fomo.html)
// last N Buyers stored in Array(Address, N)
// 3. Communication Construction
// 3.1. The Funder publishes the ticket price, deadline, and unit price
// 3.2. While the deadline has yet to be reached:
// 3.2a. Allow a Buyer to purchase a ticket
// 3.2b. Keep track of winners (last N Buyers)
// 3.2c. Payout dividends to Buyers identified as winners and funder
// 3.3 Divide balance evenly amongst the winners
// 3.4 Transfer reward to each winner
// 4. Assertion Insertion
// 5. Interaction Introduction
// 6. Deployment Descisions

// FOMO Workshop generalized to last N winners (https://docs.reach.sh/workshop-fomo-generalized.html)
// Additional features
// - Slightly increasing the ticket price with each purchase
// - Introducing a small payout system (dividends) to Buyers
//   as the game progresses. e.g. every time the ring buffer
//   is filled.
//   + show Participant balance after dividend payout

// TODO (1) may require number of winners from Funder 
// TODO (2) add web interface (react)
// TODO (3) modify the command line frontend to play until a participcant reaches a goal

const NUM_OF_WINNERS = 2; // TODO (1) may require number of winners from funder 

const CommonInterface = {
  // show the address of winner
  showOutcome: Fun([Array(Address, NUM_OF_WINNERS)], Null),
  showBalance: Fun([], Null),
};

const FunderInterface = {
  ...CommonInterface,
  getParams: Fun([], Object({
    deadline: UInt, // relative deadline
    ticketPrice: UInt, // initial price of ticket
    unitPrice: UInt // affect how the ticket price changes as tickets or sold (Note, unitPrice of 0 keeps ticket price constant)
  }))
};

const BuyerInterface = {
  ...CommonInterface,
  shouldBuyTicket: Fun([UInt], Bool),
  showPurchase: Fun([Address, UInt, UInt], Null)
};

export const main = Reach.App(
  {},
  [
    Participant('Funder', FunderInterface),
    ParticipantClass('Buyer', BuyerInterface)
  ],
  (Funder, Buyer) => {

    const showOutcome = (winners) =>
      each([Funder, Buyer], () => interact.showOutcome(winners));

    // 3.1. The Funder publishes the ticket price, deadline, and unit price
    Funder.only(() => {
      const { ticketPrice, deadline, unitPrice } = declassify(interact.getParams());
    })
    Funder.publish(ticketPrice, deadline, unitPrice);

    // Initialize winner array to Funder
    const initialWinners = Array.replicate(NUM_OF_WINNERS, Funder);

    // 3.2. While the deadline has yet to be reached:
    const [keepGoing, winners, ticketSold] =
      parallelReduce([true, initialWinners, 0])
        .invariant(balance() === 0
              + ticketPrice * ticketSold // balance attributed to tickets sold
              + unitPrice * ticketSold * (ticketSold - 1) / 2 // balance attributed to unit price
              - 3 * ticketSold * unitPrice // negative balance attributed to dividend payout
        )
        .while(keepGoing)
        .case(
          Buyer,
          // 3.2a. Allow a Buyer to purchase a ticket
          (() => ({
            when: declassify(interact.shouldBuyTicket(ticketPrice))
          })),
          ((_) => ticketPrice + unitPrice * ticketSold),
          ((_) => {
            const buyer = this;
            const idx = ticketSold % NUM_OF_WINNERS;

            // -----------------------------------
            // 3.2b. Keep track of winners (last N Buyers)
            // -----------------------------------
            Buyer.only(() =>
              interact.showPurchase(buyer, ticketPrice + unitPrice * ticketSold, ticketSold / NUM_OF_WINNERS * unitPrice));
            // -----------------------------------

            // -----------------------------------
            // 3.2c. Payout dividends to Buyers identified as winners and Funder
            // dividend payout to ring buffer occupants and Funder 
            // Notes:
            // (1) incentive for Funder to deploy contract as 
            //     the balance of the Funder always increases
            // (2) incentive for Buyer to
            //     participate early as
            //       cost of losing near zero with chance of receiving dividend payout
            //     participate later as
            //       reward for winning increase as more tickets are sold
            // -----------------------------------
            transfer(unitPrice).to(Funder);
            transfer(unitPrice*2).to(winners[0]);
            // show Participant balance after dividend payout
            each([Funder, Buyer], () => interact.showBalance());
            // -----------------------------------

            return [true, Array.set(winners, idx, buyer), ticketSold + 1];
          }))
        .timeout(deadline, () => {
          Anybody.publish();
          return [false, winners, ticketSold];
        });

    // 3.3 Divide balance evenly amongst the winners
    transfer(balance() % NUM_OF_WINNERS).to(Funder);
    const reward = balance() / NUM_OF_WINNERS;

    // 3.4 Transfer reward to each winner
    winners.forEach(winner =>
      transfer(reward).to(winner));

    commit();
    showOutcome(winners);
  });
