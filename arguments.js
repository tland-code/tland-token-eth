require('dotenv').config()

module.exports = [
  process.env.WALLET_ADDRESS,
  process.env.AUTHORIZER_ADDRESS,
  process.env.CAP,
  process.env.OPENING_TIME,
  process.env.CLOSING_TIME,
  process.env.TOKEN_PRICE,
  [process.env.ACCEPTED_PAYMENT_TOKEN],
];
