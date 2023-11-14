const fs = require("fs");
const prompt = require("prompt-sync")({ sigint: true });
const publishableKey = prompt("Publishable Key : ");
const secretKey = prompt("Secret Key : ");
const serverURL = prompt("Self-hosted Hyperswitch Server URL : ");
const clientURL = prompt("Self-hosted Hyperswitch Client URL : ");

const appServerURL = prompt("Application Server URL : ");
const appClientURL = prompt("Application Client URL : ");

const envPath = "./.env";

const publishableKeyDesc = "Publishable key added";
const secretKeyDesc = "Secret key added";
const serverURLDesc = "Self-hosted Hyperswitch Server URL added";
const clientURLDesc = "Self-hosted Hyperswitch Client URL added";
const appServerURLDesc = "Application Server URL added";
const appClientURLDesc = "Application Client URL added";

function replace(filePath, oldLine, newLine, desc) {
  try {
    // Step 1: Read the file
    let data = fs.readFileSync(filePath, "utf8");

    // Step 2: Replace the line
    data = data.replaceAll(oldLine, newLine);

    // Step 3: Write the updated content back to the file
    fs.writeFileSync(filePath, data);

    console.log(`${desc} successfully.`);
  } catch (error) {
    console.error(`Error: ${error.message}`);
  }
}
replace(envPath, "SELF_HOSTED_CLIENT_URL", clientURL, clientURLDesc);
replace(
  envPath,
  "ENTER_YOUR_CLIENT_APPLICATION_URL",
  appClientURL,
  appClientURLDesc
);
replace(
  envPath,
  "ENTER_YOUR_SERVER_APPLICATION_URL",
  appServerURL,
  appServerURLDesc
);

replace(
  envPath,
  "GET_PUBLISHABLE_KEY_FROM_DASHBOARD",
  publishableKey,
  publishableKeyDesc
);
replace(envPath, "GET_SECRET_KEY_FROM_DASHBOARD", secretKey, secretKeyDesc);
replace(envPath, "SELF_HOSTED_SERVER_URL", serverURL, serverURLDesc);
