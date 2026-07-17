const fs = require('fs/promises');
const os = require('os');
const path = require('path');

const EXCLUDED_DIRECTORIES = new Set([
    'Cache',
    'Code Cache',
    'GPUCache',
    'Service Worker',
    'ShaderCache',
    'GrShaderCache',
    'GraphiteDawnCache',
]);

const getChromeUserDataDirectory = () => {
    if (process.env.CHROME_USER_DATA_DIR) {
        return path.resolve(process.env.CHROME_USER_DATA_DIR);
    }

    switch (process.platform) {
        case 'darwin':
            return path.join(os.homedir(), 'Library', 'Application Support', 'Google', 'Chrome');
        case 'win32': {
            const localAppData = process.env.LOCALAPPDATA;
            if (!localAppData) {
                throw new Error('LOCALAPPDATA is not set. Set CHROME_USER_DATA_DIR to the Chrome user-data directory.');
            }
            return path.join(localAppData, 'Google', 'Chrome', 'User Data');
        }
        default:
            return path.join(os.homedir(), '.config', 'google-chrome');
    }
};

const copyChromeProfile = async () => {
    const sourceRoot = getChromeUserDataDirectory();
    const profileName = process.env.GPAY_SOURCE_PROFILE || 'Default';
    const sourceProfile = path.join(sourceRoot, profileName);
    const targetRoot = path.resolve(
        process.env.GPAY_PROFILE_DIR || path.join(os.homedir(), 'puppeteer-chrome-profile'),
    );
    const targetProfile = path.join(targetRoot, 'Default');

    if (sourceRoot === targetRoot || targetRoot.startsWith(`${sourceRoot}${path.sep}`)) {
        throw new Error('GPAY_PROFILE_DIR must be outside the Chrome user-data directory.');
    }

    await fs.access(sourceProfile);
    await fs.access(path.join(sourceRoot, 'Local State'));

    await fs.rm(targetRoot, { recursive: true, force: true });
    await fs.mkdir(targetRoot, { recursive: true });
    await fs.cp(sourceProfile, targetProfile, {
        recursive: true,
        filter: (source) => !EXCLUDED_DIRECTORIES.has(path.basename(source)),
    });
    await fs.copyFile(path.join(sourceRoot, 'Local State'), path.join(targetRoot, 'Local State'));

    console.log(`Copied Chrome profile "${profileName}" to ${targetRoot}`);
};

copyChromeProfile().catch((error) => {
    console.error('Failed to copy the Chrome profile. Close Chrome and try again.');
    console.error(error.message);
    process.exitCode = 1;
});
