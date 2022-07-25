import * as fs from "fs";
import * as path from "path";
import { parse } from "csv-parse";

type Item = {
  address: string;
  description: string;
  balance: number;
  staked: number;
  advisorsVesting: number;
  privateVesting: number;
  submeVesting: number;
  sttVesting: number;
  sum: number;
  lpTokens: number;
  total: number;
};

const csvFilePath = path.resolve(__dirname, "snapshot.csv");

const headers = [
  "LP",
  "Address",
  "Description",
  "TLAND balance",
  "TLAND staked",
  "Advisors Vesting",
  "Private Vesting",
  "Subme Vesting",
  "STT Vesting",
  "TLAND SUM",
  "LP SUM(balance + staked)",
  "TLAND TOTAL",
  "",
  "LP MULTIPLIER",
];

const excludedAddresses = [
  // smart contracts
  "terra1h7w53kwvlqwt20j5ffsw7pysc0jww2hzyxmvkd", // lender contract
  // internal tland addresses
  "terra105mndeaenfu8e6exmarvw3q07leq2fuplclv8v", // diamond hand fee receiver
  "terra17hk7d34mg77w6ujcr6n58p8hjl9ez8w9gj6auk", // fee receiver
  "terra1xr50nhz5ecqswaehnxf7f7nvfeu0zh7424vzwe", // liquidity rest
  "terra1ly5glvd0xv5x5s4vd5x6a8p8n4pcmwn839pcep", // treasury
];

const fileContent = fs.readFileSync(csvFilePath, { encoding: "utf-8" });

parse(
  fileContent,
  {
    delimiter: ",",
    columns: headers,
    on_record: (line, context) => {
      const item: Item = {
        address: line[headers[1]],
        description: line[headers[2]],
        balance: parseInt(line[headers[3]]),
        staked: parseInt(line[headers[4]]),
        advisorsVesting: parseInt(line[headers[5]]),
        privateVesting: parseInt(line[headers[6]]),
        submeVesting: parseInt(line[headers[7]]),
        sttVesting: parseInt(line[headers[8]]),
        sum: parseInt(line[headers[9]]),
        lpTokens: parseInt(line[headers[10]]),
        total: parseInt(line[headers[11]]),
      };

      // remove items with empty total
      if (item.total === 0 || isNaN(item.total)) {
        return;
      }

      // remove excluded addresses
      if (excludedAddresses.includes(item.address)) {
        return;
      }

      return item;
    },
  },
  (error, result: Item[]) => {
    if (error) {
      console.error(error);
    }

    let total = 0;
    result.forEach((el) => {
      total += el.total;
    });

    console.log("Items number", result.length);
    console.log("Total", total);

    const jsonData = JSON.stringify(result);
    fs.writeFile("holders.json", jsonData, function (err) {
      if (err) {
        console.log(err);
      }
    });
  }
);
