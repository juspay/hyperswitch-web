# Accept a payment examples in React for Payment Element

## How to run locally

This is the React client for the sample and runs independently of the server.
Running a backend server is a requirement and a dependency for this React front-end to work. See the README in the root of the project for more details.

To run the React client locally:

1. Install dependencies

From this directory run:

```sh
npm install
```

2. Start the react app

```sh
npm start
```

This will start the react server running on localhost:5252. API requests to your backend are proxied by the
create-react-app server using the `proxy` setting in `./package.json`.

## Example config using our Sandbox URL
```
STATIC_DIR=./dist
HYPERSWITCH_PUBLISHABLE_KEY=pk_snd_*** # replace with your publishable key
HYPERSWITCH_SECRET_KEY=snd_*** # replace with your API Key
HYPERSWITCH_SERVER_URL=https://sandbox.hyperswitch.io
HYPERSWITCH_CLIENT_URL=http://localhost:9050
SELF_SERVER_URL=http://localhost:5252
PROFILE_ID=""
```

## Troubleshooting
If your demo application is not working, you can check the following to hopefully find the issue.

- Make sure you have configured the [.env](.env) file correctly.
    - Publishable Key `HYPERSWITCH_PUBLISHABLE_KEY` and API Key `HYPERSWITCH_SECRET_KEY` belong to the server `HYPERSWITCH_SERVER_URL`. If you use our Sandbox URL, use publishable key and API key from the hyperswitch website. If you are using your self-hosted backend, use your locally created publishable key and API Key.
    - The URL's must not have a slash at the end.
- Check that you have opened the demo application on the correct port. The default should be [localhost:5252](http://localhost:5252). Check the [webpack.common.js](./webpack.common.js) file to see if it is different.
- Make sure you have three terminal windows open and running. If you are running your local backend, it is one more.
- Open your browser's development tools (F12 in most browsers) and check the network tab for failed rest calls and the console for errors. 
