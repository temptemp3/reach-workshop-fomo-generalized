'reach 0.1';
'use strict';


// 1. Problem Analysis
// What funds change ownership during the application?
// Buyers continually add funds to the balance during execution until the last N Buyers, and potentially the Funder, split the blance.
// 2. Data Definition
// Same as Workshop: Fomo
// last N Buyers stored in Array(Address, N)
// 3. Communication Construction
// 3.1. The Funder publishes the ticket price and deadline while initializing the winnner array with self
// 3.2. While the deadline has yet to be reached:
// 3.2a. Allow a Buyer to purchase a ticket
// 3.2b. Keep track of winners (last N Buyers)
// 3.3 Divide balance evenly amongst the winners
// 3.4 Transfer reward to each winner
// 4. Assertion Insertion
// 5. Interaction Introduction
// 6. Deployment Descisions

// FOMO Workshop generalized to last N winners

const NUM_OF_WINNERS = 1;

const CommonInterface = {
  // Show the address of winner
  showOutcome: Fun([Array(Address, NUM_OF_WINNERS)], Null),
};

const FunderInterface = {
  ...CommonInterface,
  getParams: Fun([], Object({
    deadline: UInt, // relative deadline
    ticketPrice: UInt
  }))
};

const BuyerInterface = {
  ...CommonInterface,
  shouldBuyTicket: Fun([UInt], Bool),
  showPurchase: Fun([Address], Null)
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

    // 3.1. The Funder publishes the ticket price and deadline
    Funder.only(() => {
      const { ticketPrice, deadline } = declassify(interact.getParams());
    })
    Funder.publish(ticketPrice, deadline);

    // Initialize winner array to Funder
    const initialWinners = Array.replicate(NUM_OF_WINNERS, Funder);

    // 3.2. While the deadline has yet to be reached:
    const [keepGoing, winners, ticketSold] =
      parallelReduce([true, initialWinners, 0])
        .invariant(balance() == ticketPrice * ticketSold)
        .while(keepGoing)
        .case(
          Buyer,
          // 3.2a. Allow a Buyer to purchase a ticket
          (() => ({
            when: declassify(interact.shouldBuyTicket(ticketPrice))
          })),
          ((_) => ticketPrice),
          ((_) => {
            const buyer = this;
            // 3.2b. Keep track of winners (last N Buyers)
            Buyer.only(() => interact.showPurchase(buyer));
            const idx = ticketSold % NUM_OF_WINNERS;
            const newWinners =
              Array.set(winners, idx, buyer);
            return [true, newWinners, ticketSold + 1];
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
