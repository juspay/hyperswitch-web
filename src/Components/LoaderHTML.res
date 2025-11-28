// Type definitions
type document

// External bindings
@val external windowOpen: (string, string, string) => Nullable.t<Types.window> = "open"

@get external getDocument: Types.window => document = "document"

@send external documentWrite: (document, string) => unit = "write"

@send external documentClose: document => unit = "close"

@send external closeWindow: Types.window => unit = "close"

// The HTML content for the payment loader
let loaderHtml = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Payment Processing</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            background: #f5f5f5;
            padding: 20px;
        }

        .container {
            text-align: center;
            width: 100%;
        }

        /* Loader Container */
        .loader-container {
            display: flex;
            flex-direction: row;
            align-items: center;
            justify-content: center;
            gap: 24px;
            width: 126px;
            height: 26px;
            margin: 0 auto 32px;
        }

        /* Blue Dots */
        .dot {
            width: 26px;
            height: 26px;
            background: #0069FF;
            border-radius: 50%;
            animation: pulse 1.4s ease-in-out infinite;
        }

        .dot:nth-child(1) {
            animation-delay: 0s;
        }

        .dot:nth-child(2) {
            animation-delay: 0.2s;
        }

        .dot:nth-child(3) {
            animation-delay: 0.4s;
        }

        /* Animation */
        @keyframes pulse {
            0%, 100% {
                transform: scale(1);
            }
            50% {
                transform: scale(1.2);
            }
        }

        /* Text Styles */
        .primary-text {
            font-size: 20px;
            font-weight: 600;
            color: #1a1a1a;
            margin-bottom: 12px;
        }

        .secondary-text {
            font-size: 14px;
            font-weight: 400;
            color: #666666;
            line-height: 1.5;
        }

        /* Responsive adjustments for small windows and mobile */
        @media screen and (max-width: 480px) {
            .primary-text {
                font-size: 18px;
            }

            .secondary-text {
                font-size: 13px;
            }

            .loader-container {
                margin-bottom: 24px;
            }
        }

        @media screen and (max-width: 360px) {
            .primary-text {
                font-size: 16px;
            }

            .secondary-text {
                font-size: 12px;
            }

            .loader-container {
                gap: 20px;
                width: 106px;
            }

            .dot {
                width: 22px;
                height: 22px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="loader-container">
            <div class="dot"></div>
            <div class="dot"></div>
            <div class="dot"></div>
        </div>
        <div class="primary-text">Please wait....</div>
        <div class="secondary-text">This may take a few seconds. Please don't go back or close this page.</div>
    </div>
</body>
</html>
`

// Function to inject the loader HTML into the opened window
let injectLoader = (windowRef: Nullable.t<Types.window>) => {
  switch windowRef->Nullable.toOption {
  | Some(win) => {
      let doc = win->getDocument
      doc->documentWrite(loaderHtml)
      doc->documentClose
    }
  | None => ()
  }
}
