const fs = require("fs");
const prompt = require("prompt-sync")({ sigint: true });
const publishableKey = prompt("Publishable Key : ");
const secretKey = prompt("Secret Key : ");
const serverURL = prompt("Self-hosted Hyperswitch Server URL : ");
const clientURL = prompt("Self-hosted Hyperswitch Client URL : ");

const appServerURL = prompt("Application Server URL : ");
const appClientURL = prompt("Application Client URL : ");

const envPath = "./.env";

const obj = {
  HYPERSWITCH_PUBLISHABLE_KEY: publishableKey,
  HYPERSWITCH_SECRET_KEY: secretKey,
  HYPERSWITCH_SERVER_URL: serverURL,
  HYPERSWITCH_CLIENT_URL: clientURL,
  SELF_SERVER_URL: appServerURL,
  SELF_CLIENT_URL: appClientURL,
};

function initializeValues(filePath, keyValuePairs) {
  try {
    let data = fs.readFileSync(filePath, "utf8");

    // Split the content by newline to operate on individual lines
    let lines = data.split("\n");

    // Process each key-value pair
    Object.entries(keyValuePairs).forEach(([key, value]) => {
      // Find if the key already exists in the .env file
      let index = lines.findIndex((line) => line.startsWith(`${key}=`));

      if (index !== -1) {
        // If the key exists, update its value
        lines[index] = `${key}="${value}"`;
      } else {
        // If the key doesn't exist, add a new line with the key-value pair
        lines.push(`${key}="${value}"`);
      }
    });

    // Join the lines back together
    data = lines.join("\n");

    // Write the updated content back to the file
    fs.writeFileSync(filePath, data);

    console.log("Initialization of values successful.");
  } catch (error) {
    console.error(`Error: ${error.message}`);
  }
}
initializeValues(envPath, obj);
