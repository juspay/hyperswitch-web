<p align="center">
  <img src="./docs/imgs/hyperswitch-logo-dark.svg#gh-dark-mode-only" alt="Hyperswitch-Logo" width="40%" />
  <img src="./docs/imgs/hyperswitch-logo-light.svg#gh-light-mode-only" alt="Hyperswitch-Logo" width="40%" />
</p>

<h1 align="center">Hyperswitch Unified Checkout</h1>

<div align="center" >
<i>Accept payments from around the globe with a secure, Unified Checkout that gives your customers the best in class payment experience</i>
<br/><br/>
Web unified checkout SDK is an inclusive, consistent and blended payment experience optimized for the best conversion rates.
<br/><br/>
<strong>Inclusive</strong>: A variety of global payment methods including cards, buy now pay later and digital wallets are supported by the Unified Checkout, with adaptation to local preferences and ability to local language customization.

<strong>Consistent</strong>: With a diverse set of payment methods supported, the Unified Checkout provides a singular consistent payment experience across platforms (web, android and ios) powered by smart payment forms, minimal redirections and intelligent retries.

<strong>Blended</strong>: The Unified Checkout includes 40+ styling APIs, which could be tweaked to make the payment experience blend with your product. Your users will get a fully native and embedded payment experience within your app or website

</div>

<p align="center">
  <a href="#%EF%B8%8F-quick-start-guide">Quick Start Guide</a> •
  <a href="#-setup-instructions">Setup Instructions</a> •
  <a href="#-fast-integration-for-stripe-users">Fast Integration for Stripe Users</a> •
  <!-- <a href="#-supported-features">Supported Features</a> • -->
  <a href="#-Connect-your-Hyperswitch-self-hosted-Server">Connect your Hyperswitch self Hosted Server</a> •
  <a href="#-FAQs">FAQs</a>
  <br>
  <a href="#-join-us-in-building-hyperswitch">Join us in building HyperSwitch</a> •
  <a href="#-community">Community</a> •
  <a href="#-bugs-and-feature-requests">Bugs and feature requests</a> •
  <a href="#-versioning">Versioning</a> •
  <a href="#%EF%B8%8F-copyright-and-license">Copyright and License</a>
</p>

<p align="center">
  <!-- <a href="https://github.com/juspay/hyperswitch-web/actions?query=workflow%3ACI+branch%3Amain">
    <img src="https://github.com/juspay/hyperswitch-web/workflows/CI/badge.svg" />
  </a> -->
  <a href="https://github.com/juspay/hyperswitch-web/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/juspay/hyperswitch-web" />
  </a>
  <a href="https://github.com/juspay/hyperswitch-web/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/Made_with-Rescript-blue" />
  </a>
</p>

<img src="./docs/imgs/switch.png" />

While the Unified Checkout is pre-optimized for maximum conversions, it does not restrict you to stick to a one-size-fits-all approach. Using the SDK APIs, you get complete control over modifying the payment experience by,

- 📝 **Including new fields to the payment form** on a single processor like Stripe or Braintree
- 💳 **Prioritizing payment methods** by 90% to add & maintain integrations
- 🎨 **Switching themes and layouts of checkout page** with full visibility and control

<br>

<a href="#Quick Start Guide">
  <h2 id="Quick Start Guide">⚡️ Quick Start Guide</h2>
</a>

<a href="https://app.hyperswitch.io/register"><img src="./docs/imgs/signup-to-hs.svg" height="35"></a>

Ways to get started with Hyperswitch:

- Try it in our Sandbox Environment: Fast and easy to
  start.

<a href="https://app.hyperswitch.io/register"><img src="./docs/imgs/get-api-keys.svg" height="35"></a>

- Install in your local system: Configurations and setup required in your system. Suitable if you like to customise the core offering, [learn more](https://github.com/juspay/hyperswitch/blob/main/docs/try_local_system.md)

<a href="#Setup-Instructions">
  <h2 id="Setup Instructions">🛠️ Setup Instructions</h2>
</a>

### Setup Node

Check if your machine has node already installed by running the below command on your local machine.

```bash
node -v
```

If your machine does not have node installed in it, you can install it from [here](https://nodejs.org/en/download)

### Clone the repository

Clone the repository from Bitbucket and save in your folder.

```bash
git clone https://github.com/juspay/hyperswitch-web.git
cd hyperswitch-web
```

### Setup the repository

First install all the node modules by running the following command

```bash
npm install
```

Replace the placeholders in /Hyperswitch-react-demo-app/.env publishable key and secret key

```
HYPERSWITCH_PUBLISHABLE_KEY=<GET_THIS_FROM_DASHBOARD>
HYPERSWITCH_SECRET_KEY=<GET_THIS_FROM_DASHBOARD>
```

In the package json file you can see the various scripts you can run.
To start compiling the Rescript code, run the following command. Whenever there is a change in the Rescript code, the compiler will build its adjacent JS code which will be consumed.

```bash
npm run re:start
```

Start the webpack development server by running this command. This will trigger webpack to build a `dist` folder which will contain all the assets and serve it to port localhost:9050 (which you can change from within `webpack.common.js`)

```bash
npm run start
```

You will now get the url http://localhost:9050/HyperLoader.js, which is the script tag.

To see your Web Client functioning you can run the command below, this will open up a playground in which your immediate changes should reflect as you proceed with your development.

```bash
npm run start:playground
```

### About Env Configs

For ease of development and deployment there are configs in /Hyperswitch-react-demo-app/.env

- `HYPERSWITCH_PUBLISHABLE_KEY` - Publishable key of your Hyperswitch Account
- `HYPERSWITCH_SECRET_KEY` - Api key of your Hyperswitch Account
- `HYPERSWITCH_SERVER_URL` - URL of your hosted Hyperswitch Backend server
- `HYPERSWITCH_CLIENT_URL` - URL of your hosted Hyperswitch SDK
- `SELF_SERVER_URL` - URL of your node server (/Hyperswitch-react-demo-app/server.js)
- `SELF_CLIENT_URL` - URL where your application is running

### Logging

Logging from the payment checkout web client is crucial for tracking and monitoring the flow of payments. It provides a transparent record of events, errors, and user interactions, aiding developers and support teams in identifying issues, debugging, and ensuring the security and reliability of payment processes. Well-implemented logging enhances traceability and facilitates a more efficient resolution of potential problems in the payment checkout experience.

Logs are sent to the server via non-blocking Beacon API requests. This means that even if the logging endpoint configured is incorrect, it would not affect the core payment functionalities. You can find more about the structure of logging request payload in the `beaconApiCall` function in the [`OrcaLogger.res`](./src/orca-log-catcher/OrcaLogger.res#L423C7-L423C20) file.

If you want to collect logs, you can do so by setting up an endpoint on your server to receive, process and persist logs.

In the [`webpack.common.js`](./webpack.common.js) file, you would have to enable the logging flag, and configure the logging endpoint and log level.

```javascipt
let logEndpoint =
  sdkEnv === "prod"
    ? "<YOUR_PRODUCTION_LOGGING_ENDPOINT>"
    : "<YOUR_SANDBOX_LOGGING_ENDPOINT>";

// Set this to true to enable logging
let enableLogging = true;

// Choose from DEBUG, INFO, WARNING, ERROR, SILENT
let loggingLevel = "DEBUG";
```

<br>
<div style="display: flex; align-items: center; flex-direction: column;">
  <img src="./docs/imgs/logging_levels.png" />
  <i>Understanding Logging Levels</i>
</div>
<br>

Now let's test the integration by making a payment from your web client!

<a href="#Integrate Hyperswitch on your App">
  <h2 id="Integrate Hyperswitch on your App">🔌 Integrate Hyperswitch on your App</h2>
</a>

Now that the project is up and running, integrating Hyperswitch on your web-app is fast &
easy.
Try the steps below to get a feel of how quick the setup is:

1. Get API keys from our [dashboard].
2. Follow the instructions detailed on our
   [documentation page][hyperswitch-docs].

[dashboard]: https://app.hyperswitch.io/register
[hyperswitch-docs]: https://hyperswitch.io/docs/sdkIntegrations/unifiedCheckoutWeb/

<a href="#Connect your Hyperswitch self hosted Server">
  <h2 id="Connect with you Hyperswitch Server">🔌Connect your Hyperswitch self hosted Server</h2>
</a>

Modify the `HYPERSWITCH_SERVER_URL` key in `.env file` by adding the BE hosted url

<a href="#FAQs">
  <h2 id="FAQs">🤔 FAQs</h2>
</a>

Got more questions?
Please refer to our [FAQs page][faqs].

[faqs]: https://hyperswitch.io/docs/devSupport

<!--
## Documentation

Please refer to the following documentation pages:

- Getting Started Guide [Link]
- API Reference [Link]
- Payments Fundamentals [Link]
- Installation Support [Link]
- Router Architecture [Link]
 -->

<a href="#Join-us-in-building-Hyperswitch">
  <h2 id="Join-us-in-building-Hyperswitch">💪 Join us in building Hyperswitch</h2>
</a>

### 🤝 Our Belief

> Payments should be open, fast, reliable and affordable to serve
> the billions of people at scale.

Globally payment diversity has been growing at a rapid pace.
There are hundreds of payment processors and new payment methods like BNPL,
RTP etc.
Businesses need to embrace this diversity to increase conversion, reduce cost
and improve control.
But integrating and maintaining multiple processors needs a lot of dev effort.
Why should devs across companies repeat the same work?
Why can't it be unified and reused? Hence, Hyperswitch was born to create that
reusable core and let companies build and customise it as per their specific requirements.

### ✨ Our Values

1. Embrace Payments Diversity: It will drive innovation in the ecosystem in
   multiple ways.
2. Make it Open Source: Increases trust; Improves the quality and reusability of
   software.
3. Be community driven: It enables participatory design and development.
4. Build it like Systems Software: This sets a high bar for Reliability,
   Security and Performance SLAs.
5. Maximise Value Creation: For developers, customers & partners.

### 🤍 Contributing

This project is being created and maintained by [Juspay](https://juspay.in),
South Asia's largest payments orchestrator/switch, processing more than 50
Million transactions per day. The solution has 1Mn+ lines of Haskell code built
over ten years.
Hyperswitch Web leverages our experience in building large-scale, enterprise-grade &
frictionless payment solutions.
It is built afresh for the global markets as an open-source product in Rescript.
We are long-term committed to building and making it useful for the community.

The product roadmap is open for the community's feedback.
We shall evolve a prioritisation process that is open and community-driven.
We welcome contributions from the community.

<!-- Please read through our [contributing guidelines](/docs/CONTRIBUTING.md).
Included are directions for opening issues, coding standards, and notes on
development. -->

<a href="#Community">
  <h2 id="Community">👥 Community</h2>
</a>

Get updates on Hyperswitch development and chat with the community:

- Read and subscribe to [the official Hyperswitch blog][blog].
- Join our [Discord server][discord].
- Join our [Slack workspace][slack].
<!-- - Ask and explore our [GitHub Discussions][github-discussions]. -->

[blog]: https://hyperswitch.io/blog
[discord]: https://discord.gg/wJZ7DVW8mm
[slack]: https://join.slack.com/t/hyperswitch-io/shared_invite/zt-1k6cz4lee-SAJzhz6bjmpp4jZCDOtOIg
[github-discussions]: https://github.com/juspay/hyperswitch-web/discussions

<div style="display: flex;  justify-content: center;">
    <div style="margin-right:10px">
    <a href="https://www.producthunt.com/posts/hyperswitch-2?utm_source=badge-top-post-badge&utm_medium=badge&utm_souce=badge-hyperswitch&#0045;2" target="_blank">
        <img src="https://api.producthunt.com/widgets/embed-image/v1/top-post-badge.svg?post_id=375220&theme=light&period=weekly" alt="Hyperswitch - Fast, reliable, and affordable open source payments switch | Product Hunt" style="width: 250px; height: 54px;" width="250" height="54" />
    </a>
    </div>
    <div style="margin-right:10px">
    <a href="https://www.producthunt.com/posts/hyperswitch-2?utm_source=badge-top-post-topic-badge&utm_medium=badge&utm_souce=badge-hyperswitch&#0045;2" target="_blank">
        <img src="https://api.producthunt.com/widgets/embed-image/v1/top-post-topic-badge.svg?post_id=375220&theme=light&period=weekly&topic_id=267" alt="Hyperswitch - Fast, reliable, and affordable open source payments switch | Product Hunt" style="width: 250px; height: 54px;" width="250" height="54" />
    </a>
  </div>
  <div style="margin-right:10px">
    <a href="https://www.producthunt.com/posts/hyperswitch-2?utm_source=badge-top-post-topic-badge&utm_medium=badge&utm_souce=badge-hyperswitch&#0045;2" target="_blank">
        <img src="https://api.producthunt.com/widgets/embed-image/v1/top-post-topic-badge.svg?post_id=375220&theme=light&period=weekly&topic_id=93" alt="Hyperswitch - Fast, reliable, and affordable open source payments switch | Product Hunt" style="width: 250px; height: 54px;" width="250" height="54" />
    </a>
  </div>
</div>

<a href="#Bugs and feature requests">
  <h2 id="Bugs and feature requests">🐞 Bugs and feature requests</h2>
</a>

Please read the issue guidelines and search for [existing and closed issues].
If your problem or idea is not addressed yet, please [open a new issue].

[existing and closed issues]: https://github.com/juspay/hyperswitch-web/issues
[open a new issue]: https://github.com/juspay/hyperswitch-web/issues/new/choose

<!-- <a href="#Versioning">
  <h2 id="Versioning">🔖 Versioning</h2>
</a>

Check the [CHANGELOG.md](./CHANGELOG.md) file for details. -->

<a href="#©Copyright and License">
  <h2 id="©Copyright and License">©️ Copyright and License</h2>
</a>

This product is licensed under the [Apache 2.0 License](LICENSE).

<a href="#Thanks to all contributors">
  <h2 id="Thanks to all contributors">✨ Thanks to all contributors</h2>
</a>

Thank you for your support in hyperswitch's growth. Keep up the great work! 🥂

<a href="https://github.com/juspay/hyperswitch-web/graphs/contributors">
  <img src="https://contributors-img.web.app/image?repo=juspay/hyperswitch-web" alt="Contributors"/>
</a>
