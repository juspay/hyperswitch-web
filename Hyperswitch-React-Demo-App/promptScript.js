const fs = require("fs");
const prompt = require("prompt-sync")({ sigint: true });

const envPath = "./.env";

const obj = {
  HYPERSWITCH_PUBLISHABLE_KEY: "Publishable Key",
  HYPERSWITCH_SECRET_KEY: "Secret Key",
  HYPERSWITCH_SERVER_URL: "Self-hosted Hyperswitch Server URL (URL of your Hyperswitch Backend)",
  HYPERSWITCH_CLIENT_URL: "Self-hosted Hyperswitch Client URL (URL of your Hyperswitch SDK)",
  SELF_SERVER_URL: "Application Server URL (URL of your node server)",
  SELF_CLIENT_URL: "Application Client URL (URL where your application is running)",
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
        if (lines[index] === `${key}=` || lines[index] === `${key}=""`) {
          const promptVal = prompt(`${value} : `)
          // If the key exists, and has not been updated once, update its value
          lines[index] = `${key}="${promptVal}"`;
        }
      } else {
        const promptVal = prompt(`${value} : `)
        // If the key doesn't exist, add a new line with the key-value pair
        lines.push(`${key}="${promptVal}"`);
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
