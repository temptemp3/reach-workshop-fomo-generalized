import { loadStdlib, getConnector } from '@reach-sh/stdlib';
import * as backend from './build/index.main.mjs';

const numberOfBuyers = 5;

(async () => {

  const stdlib = await loadStdlib();
  const connector = getConnector();
  const startingBalance = stdlib.parseCurrency(100);

  const accFunder = await stdlib.newTestAccount(startingBalance);
  const accBuyers = await Promise.all(
    Array.from({ length: numberOfBuyers }, () =>
      stdlib.newTestAccount(startingBalance)));

  const getBalance = async (who) =>
    stdlib.formatCurrency(await stdlib.balanceOf(who), 4);

  const ctcFunder = accFunder.deploy(backend);
  const ctcInfo = ctcFunder.getInfo();

  const ticketPrice = stdlib.parseCurrency(3); //Array.from({length: numberOfBuyers}, () => stdlib.parseCurrency(3));
  const deadline = connector === 'ALGO' ? 4 : 8;
  const funderParams = {
    deadline,
    ticketPrice
  }

  const resultText = (outcome, addr) =>
    outcome.includes(addr) ? 'won' : 'lost';

  const bidHistory = {};

  await Promise.all([
    backend.Funder(ctcFunder, {
      showOutcome: (outcome) =>
        console.log(`Funder saw they ${resultText(outcome, accFunder.getAddress())}`),
      getParams: () => funderParams
    })
  ].concat(
    accBuyers.map((accBuyer, i) => {
      const ctcBuyer = accBuyer.attach(backend, ctcInfo);
      const Who = `Buyer #${i}`;
      return backend.Buyer(ctcBuyer, {
        showOutcome: (outcome) =>
          console.log(`${Who} saw they ${resultText(outcome, accBuyer.getAddress())}`),
        // considering buying if not yet bought yet and 
        // buyer wants to buy 
        shouldBuyTicket: () =>
          !bidHistory[Who] && Math.random() < .5,
        showPurchase: (addr) => {
          if (stdlib.addressEq(addr, accBuyer)) {
            console.log(`${Who} bought a ticket.`);
            bidHistory[Who] = true;
          }
        }
      });
    })
  ));

  console.log(`Funder balance now ${await getBalance(accFunder)}`)
  accBuyers.map(async (accBuyer, i) => {
    const Who = `Buyer #${i}`;
    console.log(`${Who} balance now ${await getBalance(accBuyer)}`)
  });

})();
