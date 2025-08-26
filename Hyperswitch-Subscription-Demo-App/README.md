# Hyperswitch Subscription Demo App

A comprehensive React demo application showcasing Hyperswitch's subscription capabilities, including plan selection, coupon handling, trial periods, and payment processing.

## Features

### 🎯 Core Subscription Features
- **Plan Selection**: Multiple subscription tiers with different features
- **Trial Periods**: Free trial support with automatic billing after trial ends
- **Coupon System**: Apply discount coupons with real-time price updates
- **Real-time Pricing**: Dynamic price calculation with discounts and taxes
- **Payment Processing**: Secure payment handling via Hyperswitch SDK

### 🎨 User Experience
- **Responsive Design**: Works seamlessly on desktop and mobile
- **Interactive UI**: Real-time updates and smooth transitions
- **Error Handling**: Comprehensive error messages and validation
- **Loading States**: Clear feedback during API calls

### 🔧 Technical Features
- **Mock Backend**: Complete mock API for demonstration
- **Hyperswitch Integration**: Full SDK integration with payment elements
- **Modular Components**: Reusable React components
- **Modern Styling**: CSS Grid, Flexbox, and modern design patterns

## Available Plans

### Basic Plan - $9.99/month
- Up to 5 projects
- 10GB storage
- Email support
- Basic analytics

### Pro Plan - $29.99/month (Most Popular)
- Unlimited projects
- 100GB storage
- Priority support
- Advanced analytics
- Team collaboration
- API access
- **14-day free trial**

### Enterprise Plan - $99.99/month
- Everything in Pro
- Unlimited storage
- 24/7 phone support
- Custom integrations
- Advanced security
- Dedicated account manager
- **30-day free trial**

## Available Coupons

Test the coupon functionality with these codes:
- `SAVE20` - 20% off your subscription
- `WELCOME25` - 25% off for new customers
- `SUMMER30` - Summer special - 30% off

## Getting Started

### Prerequisites
- Node.js (v14 or higher)
- npm or yarn
- Hyperswitch account (for real payment processing)

### Installation

1. **Clone the repository** (if not already done)
   ```bash
   git clone <repository-url>
   cd hyperswitch-web/Hyperswitch-Subscription-Demo-App
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Configure environment variables**
   ```bash
   cp .env.example .env
   ```
   
   Update the `.env` file with your Hyperswitch credentials:
   ```env
   HYPERSWITCH_PUBLISHABLE_KEY=your_publishable_key
   HYPERSWITCH_SECRET_KEY=your_secret_key
   PROFILE_ID=your_profile_id
   HYPERSWITCH_SERVER_URL=https://sandbox.hyperswitch.io
   HYPERSWITCH_CLIENT_URL=https://beta.hyperswitch.io/v1
   ```

4. **Start the development server**
   ```bash
   npm start
   ```

5. **Access the application**
   - Frontend: http://localhost:9061
   - Backend API: http://localhost:5253

## Project Structure

```
Hyperswitch-Subscription-Demo-App/
├── public/
│   ├── subscriptionIndex.html    # Main HTML template
│   ├── manifest.json            # PWA manifest
│   └── favicon.ico              # App icon
├── src/
│   ├── components/              # React components
│   │   ├── PlanSelector.js      # Plan selection component
│   │   ├── PaymentSection.js    # Payment form component
│   │   ├── CouponInput.js       # Coupon application component
│   │   └── PriceSummary.js      # Price breakdown component
│   ├── utils/
│   │   └── subscriptionUtils.js # Utility functions and mock data
│   ├── App.js                   # Main app component
│   ├── App.css                  # Application styles
│   ├── SubscriptionFlow.js      # Main subscription flow
│   ├── index.js                 # React entry point
│   └── index.css                # Global styles
├── server.js                    # Express backend server
├── webpack.common.js            # Webpack configuration
├── webpack.dev.js               # Development webpack config
├── package.json                 # Dependencies and scripts
└── .env                         # Environment variables
```

## API Endpoints

### Configuration
- `GET /config` - Get Hyperswitch configuration
- `GET /urls` - Get server and client URLs

### Subscription Management
- `GET /subscription/plans` - Fetch available subscription plans
- `POST /subscription/create-session` - Create subscription payment session
- `POST /subscription/apply-coupon` - Apply coupon to subscription

## Component Architecture

### SubscriptionFlow (Main Component)
- Manages overall subscription state
- Handles plan selection and payment flow
- Integrates with Hyperswitch SDK

### PlanSelector
- Displays available subscription plans
- Handles plan selection logic
- Shows trial badges and popular indicators

### PaymentSection
- Integrates Hyperswitch payment elements
- Handles payment submission
- Manages payment state and errors

### CouponInput
- Coupon code input and validation
- Real-time coupon application
- Coupon removal functionality

### PriceSummary
- Dynamic price calculation
- Discount breakdown
- Trial period information

## Styling

The application uses modern CSS with:
- **CSS Grid** for layout structure
- **Flexbox** for component alignment
- **CSS Variables** for consistent theming
- **Responsive Design** for mobile compatibility
- **Smooth Animations** for better UX

## Mock Data

For demonstration purposes, the app includes:
- **Mock Plans**: Three subscription tiers with different features
- **Mock Coupons**: Various discount codes for testing
- **Mock Payment Flow**: Simulated payment processing

## Integration with Hyperswitch

The demo integrates with Hyperswitch through:
- **Payment Elements**: Secure payment form components
- **Payment Intents**: Server-side payment intent creation
- **Webhooks**: Payment status handling (in production)
- **Metadata**: Subscription context in payment data

## Development

### Available Scripts
- `npm start` - Start development server
- `npm run build` - Build for production
- `npm run format` - Format code with Prettier

### Environment Variables
- `HYPERSWITCH_PUBLISHABLE_KEY` - Your Hyperswitch publishable key
- `HYPERSWITCH_SECRET_KEY` - Your Hyperswitch secret key
- `PROFILE_ID` - Your Hyperswitch profile ID
- `HYPERSWITCH_SERVER_URL` - Hyperswitch server URL
- `HYPERSWITCH_CLIENT_URL` - Hyperswitch client URL
- `SDK_VERSION` - SDK version (v1 or v2)

## Production Deployment

For production deployment:

1. **Build the application**
   ```bash
   npm run build
   ```

2. **Configure production environment variables**
   - Update `.env` with production Hyperswitch credentials
   - Set appropriate server URLs

3. **Deploy to your hosting platform**
   - The built files will be in the `dist` directory
   - Ensure both frontend and backend are deployed

## Customization

### Adding New Plans
1. Update the `SUBSCRIPTION_PLANS` array in `server.js`
2. Add corresponding plan data in `subscriptionUtils.js`
3. Restart the development server

### Adding New Coupons
1. Update the `MOCK_COUPONS` object in `server.js`
2. Add corresponding coupon data in `subscriptionUtils.js`
3. Test the new coupon codes

### Styling Customization
1. Modify CSS variables in `App.css` for theme changes
2. Update component-specific styles as needed
3. Ensure responsive design is maintained

## Troubleshooting

### Common Issues

1. **Payment SDK not loading**
   - Check your Hyperswitch credentials
   - Verify the client URL is correct
   - Check browser console for errors

2. **Coupon codes not working**
   - Ensure coupon codes match exactly (case-sensitive)
   - Check server logs for validation errors

3. **Styling issues**
   - Clear browser cache
   - Check for CSS conflicts
   - Verify responsive design on different screen sizes

### Support

For issues related to:
- **Hyperswitch Integration**: Check Hyperswitch documentation
- **Demo App**: Create an issue in the repository
- **Payment Processing**: Contact Hyperswitch support

## License

This demo application is provided as-is for demonstration purposes. Please refer to the main repository license for usage terms.
