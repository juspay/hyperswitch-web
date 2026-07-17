# Google Pay Wallet Automation

This folder contains a standalone Puppeteer automation script for the Google Pay wallet flow.

The script is not part of the standard Cypress run. It launches Google Chrome with a copied Chrome user profile, opens the Hyperswitch demo store, enters the payment element iframe, clicks Google Pay, confirms the Google Pay sheet, and verifies that the demo page shows `Payment succeeded`.

## Prerequisites

- Run commands from the repository root.
- Install Google Chrome.
- Use a Chrome profile that is already signed in to a Google account and can complete Google Pay on the demo store.
- Close Chrome before copying or refreshing the profile.
- Keep the copied profile local. It can contain login/session data and must not be committed or shared.

## Setup and run

Each command works on macOS, Linux, Windows Command Prompt, and Windows PowerShell.

1. Install the test dependencies:

```text
npm --prefix googlepay-test install
```

2. Close Chrome, then create the test profile:

```text
npm --prefix googlepay-test run profile:setup
```

Run this command again whenever the signed-in Chrome profile needs to be refreshed. It replaces the previous copied profile.

3. Run the Google Pay test:

```text
npm --prefix googlepay-test test
```

The test launches Chrome, completes the wallet flow, and reports whether the demo page shows `Payment succeeded`.

## Optional configuration

The default paths work with a standard Google Chrome installation and its `Default` profile. These environment variables can override them:

- `CHROME_PATH`: Chrome executable used to run the test.
- `CHROME_USER_DATA_DIR`: source Chrome user-data directory used during profile setup.
- `GPAY_SOURCE_PROFILE`: source profile folder name. Defaults to `Default`.
- `GPAY_PROFILE_DIR`: destination copied profile. Defaults to `~/puppeteer-chrome-profile`.
