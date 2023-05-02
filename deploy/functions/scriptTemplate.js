const { Pact, signWithChainweaver } = require("@kadena/client");
const { listen } = require("@kadena/chainweb-node-client");

const MAX_RETRIES = 10; // Max retries allowed for chainweb queries
const RETRIES_TIMER = 10000; // Timer to retrie request
const MODULE_NAME = ""; // Module name to call
const FUNCTION_NAME = ""; // Name of the module function to call
const GAS_LIMIT = 100000; // Transaction gas limit
const GAS_PRICE = 0.00001; // Transaction gas price
const NETWORK_ID = "testnet04"; // Network id (default set on testnet)
const CHAIN_ID = 1; // Chain id
const API_HOST = `https://api.testnet.chainweb.com/chainweb/0.0/${NETWORK_ID}/chain/${CHAIN_ID}/pact`;
const GAS_PAYER_ACCOUNT =
  ""; // Account paing for gas
const GAS_PAYER_KEY =
  ""; // Account public key paing for gas
const ADMIN_KEY =
  ""; // Admin signing key (for gov operations)
const PUBLIC_USER_KEY =
  ""; // User signing key

// Execute smart contract interaction
async function executeContract(account) {
  const builder = Pact.modules[MODULE_NAME][FUNCTION_NAME](account)
    .addCap("coin.GAS", GAS_PAYER_KEY)
    .addCap("", ADMIN_KEY)
    .setMeta(
      {
        gasLimit: GAS_LIMIT,
        gasPrice: GAS_PRICE,
        sender: GAS_PAYER_ACCOUNT,
      },
      NETWORK_ID
    )
    .addData({
      "admin-keyset": [ADMIN_KEY],
    });

  // Call chainweaver wallet for trx signing
  const signatures = await signWithChainweaver(builder);

  let response = {};
  let finalResponse = {};
  let retries = 0;

  // Query chainweb for for request keys
  while (Object.keys(response).length === 0 && retries < MAX_RETRIES) {
    console.log("Tring to aquire request keys...");
    try {
      response = await Promise.race([
        signatures[0].send(API_HOST),
        new Promise((_, reject) =>
          setTimeout(
            () => reject(new Error("Timeout... Tring again.")),
            RETRIES_TIMER
          )
        ),
      ]);
    } catch (error) {
      console.error(`Error in send(): ${error.message}`);
    }

    retries++;
  }

  if (Object.keys(response).length === 0) {
    console.error(
      `Failed to get response for send() after ${MAX_RETRIES} retries.`
    );
    return;
  } else {
    console.log(`Response received after ${retries} retries.`);
    console.log(response);
    retries = 0;
  }

  console.log("-------------------------------------------------");

  // Query chainweb for response
  while (Object.keys(finalResponse).length === 0 && retries < MAX_RETRIES) {
    console.log("Awating response from chain...");
    try {
      finalResponse = await Promise.race([
        listen({ listen: response.requestKeys[0] }, API_HOST),
        new Promise((_, reject) =>
          setTimeout(
            () => reject(new Error("Timeout... Tring again.")),
            RETRIES_TIMER
          )
        ),
      ]);
    } catch (error) {
      console.error(`Error in listen(): ${error.message}`);
    }

    retries++;
  }

  if (Object.keys(finalResponse).length === 0) {
    console.error(`Failed to get response after ${MAX_RETRIES} retries.`);
    return;
  } else {
    console.log(`Response received after ${retries} retries.`);
    console.log(finalResponse.result.data[0]);
    return;
  }

  // Force function exit on hang
  return;
}

executeContract('some data').catch(console.error);
