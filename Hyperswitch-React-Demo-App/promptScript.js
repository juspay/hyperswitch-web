const fs = require("fs");
const prompt = require("prompt-sync")({ sigint: true });
const publishableKey = prompt("Publishable Key : ");
const secretKey = prompt("Secret Key : ");
const serverURL = prompt("Server URL : ");
const clientURL = prompt("Client URL : ");

const envPath = "./.env";
const patchPath = "./patches/@juspay-tech+hyper-js+1.6.0";

const publishableKeyDesc = "Publishable key added";
const secretKeyDesc = "Secret key added";
const serverURLDesc = "Server URL added";
const clientURLDesc = "Client URL added";

function replace(filePath, oldLine, newLine, desc) {
  try {
    // Step 1: Read the file
    let data = fs.readFileSync(filePath, "utf8");

    // Step 2: Replace the line
    data = data.replace(oldLine, newLine);

    // Step 3: Write the updated content back to the file
    fs.writeFileSync(filePath, data);

    console.log(`${desc} successfully.`);
  } catch (error) {
    console.error(`Error: ${error.message}`);
  }
}

replace(
  envPath,
  "GET_PUBLISHABLE_KEY_FROM_DASHBOARD",
  publishableKey,
  publishableKeyDesc
);
replace(envPath, "GET_SECRET_KEY_FROM_DASHBOARD", secretKey, secretKeyDesc);
replace(envPath, "SELF_HOSTED_SERVER_URL", serverURL, serverURLDesc);
replace(patchPath, "http://localhost:9050", clientURL, clientURLDesc);
