/** @type {import('jest').Config} */
module.exports = {
  testEnvironment: 'jest-environment-jsdom',
  testMatch: [
    '<rootDir>/__tests__/**/*.test.ts',
    '<rootDir>/src/__tests__/**/*.test.ts',
  ],
  testPathIgnorePatterns: [
    '/node_modules/',
    '/cypress-tests/',
  ],
  transform: {
    '\\.bs\\.js$': ['babel-jest', {
      presets: ['@babel/preset-env', '@babel/preset-react'],
    }],
    '\\.tsx?$': ['ts-jest', {
      tsconfig: 'tsconfig.test.json',
    }],
    '\\.mjs$': ['babel-jest', {
      presets: ['@babel/preset-env'],
    }],
    '\\.js$': ['babel-jest', {
      presets: ['@babel/preset-env'],
    }],
  },
  transformIgnorePatterns: [
    'node_modules/(?!(@rescript|@glennsl|rescript)/)',
  ],
  moduleNameMapper: {
    '^@rescript/core/src/(.*)\\.bs\\.js$': '@rescript/core/src/$1.mjs',
    '^@rescript/react/src/(.*)\\.bs\\.js$': '<rootDir>/__mocks__/rescriptReactStub.js',
    '^/package\\.json$': '<rootDir>/package.json',
  },
  moduleFileExtensions: ['ts', 'tsx', 'js', 'jsx', 'json', 'node', 'mjs'],
  setupFiles: ['<rootDir>/jest.setup.js'],
  setupFilesAfterEnv: ['@testing-library/jest-dom'],
  collectCoverage: true,
  coverageDirectory: '<rootDir>/coverage',
  coverageReporters: ['text', 'lcov', 'json-summary'],
  collectCoverageFrom: [
    // --- Shared-code (pure logic) ---
    'shared-code/sdk-utils/validation/**/*.bs.js',
    'shared-code/sdk-utils/utils/**/*.bs.js',
    'shared-code/sdk-utils/events/**/*.bs.js',
    'shared-code/sdk-utils/types/**/*.bs.js',

    // --- src/Types (pure mappers & decoders) ---
    'src/Types/**/*.bs.js',

    // --- src/Utilities (mixed – pure helpers + impure DOM/fetch) ---
    'src/Utilities/**/*.bs.js',

    // --- Root src files with pure functions ---
    'src/CardUtils.bs.js',
    'src/Bank.bs.js',
    'src/Country.bs.js',
    'src/BrowserSpec.bs.js',

    // --- Payments: helper/record files with pure functions ---
    'src/Payments/PaymentMethodsRecord.bs.js',

    // --- LocaleStrings: helper with pure mapping logic ---
    'src/LocaleStrings/LocaleStringHelper.bs.js',

    // --- hyper-log-catcher: files with some pure exports ---
    'src/hyper-log-catcher/HyperLogger.bs.js',
    'src/hyper-log-catcher/LogAPIResponse.bs.js',

    // --- Hooks (testable with renderHook + providers) ---
    'src/Hooks/**/*.bs.js',

    // --- Context (testable with renderHook + providers) ---
    'src/Context/**/*.bs.js',

    // --- Exclusions: impure / untestable ---
    '!**/node_modules/**',
    '!**/__tests__/**',
    '!**/cypress-tests/**',
    // Recoil atoms are state declarations, not testable logic
    '!src/Utilities/RecoilAtoms.bs.js',
    '!src/Utilities/RecoilAtomsV2.bs.js',
    // Event listener manager uses window directly
    '!src/Utilities/EventListenerManager.bs.js',
    // Test utils are just constants for test IDs
    '!src/Utilities/TestUtils.bs.js',
    // Empty/optimized-away files
    '!src/Types/ACHTypes.bs.js',
    '!src/Types/HyperLoggerTypes.bs.js',
    '!src/Types/SamsungPayType.bs.js',
    '!src/Types/ThemeImporter.bs.js',
    '!src/Types/UnifiedPaymentsTypesV2.bs.js',
    '!src/Utilities/AbortController.bs.js',
    '!src/Utilities/Identity.bs.js',
    '!src/Utilities/URLModule.bs.js',
    '!src/Utilities/PaymentHelpersTypes.bs.js',
    // Shared-code hooks/components are React-dependent
    '!shared-code/sdk-utils/hooks/**',
    '!shared-code/sdk-utils/components/**',
  ],
  coveragePathIgnorePatterns: [
    '/node_modules/',
    '/cypress-tests/',
    '/__tests__/',
  ],
  testResultsProcessor: 'jest-sonar-reporter',
};
