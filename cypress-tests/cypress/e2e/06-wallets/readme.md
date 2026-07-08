# Google Pay Wallet Automation

This folder contains a standalone Puppeteer automation script for the Google Pay wallet flow:

```sh
node cypress-tests/cypress/e2e/06-wallets/gpay-test.js
```

The script is not part of the standard Cypress run. It launches Google Chrome with a copied Chrome user profile, opens the Hyperswitch demo store, enters the payment element iframe, clicks Google Pay, confirms the Google Pay sheet, and verifies that the demo page shows `Payment succeeded`.

## Prerequisites

- Run commands from the repository root.
- Install root dependencies with `npm install`.
- Install Google Chrome.
- Use a Chrome profile that is already signed in to a Google account and can complete Google Pay on the demo store.
- Close Chrome before copying or refreshing the profile.
- Keep the copied profile local. It can contain login/session data and must not be committed or shared.

The test reads these optional environment variables:

- `CHROME_PATH`: path to the Chrome executable.
- `GPAY_PROFILE_DIR`: copied Chrome user-data directory. Defaults to `~/puppeteer-chrome-profile`.

## macOS

Create the copied profile:

```sh
rm -rf "$HOME/puppeteer-chrome-profile"
mkdir -p "$HOME/puppeteer-chrome-profile/Default"
rsync -a --exclude='Cache/' --exclude='Code Cache/' --exclude='GPUCache/' --exclude='Service Worker/' --exclude='ShaderCache/' --exclude='GrShaderCache/' --exclude='GraphiteDawnCache/' "$HOME/Library/Application Support/Google/Chrome/Default/" "$HOME/puppeteer-chrome-profile/Default/"
cp "$HOME/Library/Application Support/Google/Chrome/Local State" "$HOME/puppeteer-chrome-profile/"
```

Refresh the profile and run the test:

```sh
rsync -a --delete --exclude='Cache/' --exclude='Code Cache/' --exclude='GPUCache/' --exclude='Service Worker/' --exclude='ShaderCache/' --exclude='GrShaderCache/' --exclude='GraphiteDawnCache/' "$HOME/Library/Application Support/Google/Chrome/Default/" "$HOME/puppeteer-chrome-profile/Default/"
cp "$HOME/Library/Application Support/Google/Chrome/Local State" "$HOME/puppeteer-chrome-profile/"
node cypress-tests/cypress/e2e/06-wallets/gpay-test.js
```

## Linux

Create the copied profile:

```sh
rm -rf "$HOME/puppeteer-chrome-profile"
mkdir -p "$HOME/puppeteer-chrome-profile/Default"
rsync -a --exclude='Cache/' --exclude='Code Cache/' --exclude='GPUCache/' --exclude='Service Worker/' --exclude='ShaderCache/' --exclude='GrShaderCache/' --exclude='GraphiteDawnCache/' "$HOME/.config/google-chrome/Default/" "$HOME/puppeteer-chrome-profile/Default/"
cp "$HOME/.config/google-chrome/Local State" "$HOME/puppeteer-chrome-profile/"
```

Refresh the profile and run the test:

```sh
rsync -a --delete --exclude='Cache/' --exclude='Code Cache/' --exclude='GPUCache/' --exclude='Service Worker/' --exclude='ShaderCache/' --exclude='GrShaderCache/' --exclude='GraphiteDawnCache/' "$HOME/.config/google-chrome/Default/" "$HOME/puppeteer-chrome-profile/Default/"
cp "$HOME/.config/google-chrome/Local State" "$HOME/puppeteer-chrome-profile/"
CHROME_PATH="/usr/bin/google-chrome" node cypress-tests/cypress/e2e/06-wallets/gpay-test.js
```

If Chrome is installed somewhere else, update `CHROME_PATH`.

## Windows PowerShell

Create the copied profile:

```powershell
$Source = "$env:LOCALAPPDATA\Google\Chrome\User Data"
$Target = "$env:USERPROFILE\puppeteer-chrome-profile"
Remove-Item -Recurse -Force $Target -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force "$Target\Default" | Out-Null
robocopy "$Source\Default" "$Target\Default" /E /XD "Cache" "Code Cache" "GPUCache" "Service Worker" "ShaderCache" "GrShaderCache" "GraphiteDawnCache"
Copy-Item "$Source\Local State" "$Target\" -Force
```

Refresh the profile and run the test:

```powershell
$Source = "$env:LOCALAPPDATA\Google\Chrome\User Data"
$Target = "$env:USERPROFILE\puppeteer-chrome-profile"
robocopy "$Source\Default" "$Target\Default" /MIR /XD "Cache" "Code Cache" "GPUCache" "Service Worker" "ShaderCache" "GrShaderCache" "GraphiteDawnCache"
Copy-Item "$Source\Local State" "$Target\" -Force
$env:GPAY_PROFILE_DIR = $Target
$env:CHROME_PATH = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
node cypress-tests/cypress/e2e/06-wallets/gpay-test.js
```

`robocopy` may return exit code `1` even when files were copied successfully. If Chrome is installed under `Program Files (x86)`, set `CHROME_PATH` to that `chrome.exe` path before running the script.
