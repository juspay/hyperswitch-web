#!/bin/sh
echo "Starting build modifications..."
if [ -n "$envSdkUrl" ]; then
  sed -i -e "s|https://beta.hyperswitch.io/web|${envSdkUrl}/web|g" app.js HyperLoader.js
fi
if [ -n "$envBackendUrl" ]; then
  sed -i -e "s|https://beta.hyperswitch.io/api|${envBackendUrl}|g" app.js HyperLoader.js
fi
if [ -n "$envLogsUrl" ]; then
  sed -i -e "s|https://sandbox.hyperswitch.io/logs/sdk|${envLogsUrl}|g" app.js HyperLoader.js
fi
echo "Build modifications completed."
exec "$@"
