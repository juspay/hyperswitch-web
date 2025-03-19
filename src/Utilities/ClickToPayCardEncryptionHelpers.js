const keyId = "XIXBZROKXQ0PD920SVVK13xT2-op2KI_Z5xoN9d8B8gZ7ITNY";
const certPem = `-----BEGIN CERTIFICATE-----
MIIFCzCCA/OgAwIBAgIQF1JffCUP3Q4kU2kjNvae2zANBgkqhkiG9w0BAQsFADB9
MQswCQYDVQQGEwJVUzENMAsGA1UEChMEVklTQTEvMC0GA1UECxMmVmlzYSBJbnRl
cm5hdGlvbmFsIFNlcnZpY2UgQXNzb2NpYXRpb24xLjAsBgNVBAMTJVZpc2EgSW5m
b3JtYXRpb24gRGVsaXZlcnkgRXh0ZXJuYWwgQ0EwHhcNMjIxMjEzMDcxMTUxWhcN
MjUwMzEyMDcxMTUwWjCBiTEUMBIGA1UEBwwLRm9zdGVyIENpdHkxCzAJBgNVBAgM
AkNBMQswCQYDVQQGEwJVUzERMA8GA1UECgwIVmlzYSBJbmMxGDAWBgNVBAsMD091
dGJvdW5kIENsaWVudDEqMCgGA1UEAwwhZW5jLTFiZGFiM2NjLnNieC5kaWdpdGFs
LnZpc2EuY29tMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsZPIusDf
7yQnnhBkU9mu14VOO3Crui3b7rAf2KYeobURmXA17b1JX9jg0Cd+vgpmuyTrxBUS
c+4b0+UPgSwGFqPWUpx08ExqrwPDOvFojBou2wlyq8bcy0Us+BfeCzSE5lMVdSXT
XXXcNqu+qb22jCCCJALpxsArsboMOXsLedh3M4XNQ5XGAtRf7b++uTY5Dr9KLYyU
vZKAnY04MKJPEO54YiIFM5DTAhNOms089jdMdx+URIKJjPU2+RpHG1u8LCG028RT
IpPsNbRanuS5TAY/zlxDgb1hKJ36YbZENHLg9PXTBhdOMlU90DTLlfcbLTa+D7Dg
ljAaWCuvzLPaGwIDAQABo4IBeDCCAXQwDAYDVR0TAQH/BAIwADAfBgNVHSMEGDAW
gBQZOlJmzSkf4/rLNH0WdiEC2k+5GDBlBggrBgEFBQcBAQRZMFcwLgYIKwYBBQUH
MAKGImh0dHA6Ly9lbnJvbGwudmlzYWNhLmNvbS92aWNhMy5jZXIwJQYIKwYBBQUH
MAGGGWh0dHA6Ly9vY3NwLnZpc2EuY29tL29jc3AwOQYDVR0gBDIwMDAuBgVngQMC
ATAlMCMGCCsGAQUFBwIBFhdodHRwOi8vd3d3LnZpc2EuY29tL3BraTATBgNVHSUE
DDAKBggrBgEFBQcDAjBdBgNVHR8EVjBUMCigJqAkhiJodHRwOi8vRW5yb2xsLnZp
c2FjYS5jb20vVklDQTMuY3JsMCigJqAkhiJodHRwOi8vY3JsLmlub3YudmlzYS5u
ZXQvVklDQTMuY3JsMB0GA1UdDgQWBBQ1b8+Q1OXrLD7Wa2HP/QUqw3zOODAOBgNV
HQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQADggEBADktKcAGyG46aGkZcWWXPq3z
SgYlXrS27TW1xmO2nnu3mfmwFhJD3aduQU23jZy9mEVGcAxoDhIpkNDJZ2vAPSAz
47Re4eBbOFq+S8NfPe59THfxldAqhWkEOK/TfdCW/BNfv+0ML0iFenEWVm/0rliO
wCVUcGvNnNqTbLR2UnYs8gkQHQt5mLNIhvumMOJDodzUr74aEFICNa/fCpYbY8FX
Q+MwL8atUfw/QxBaO5KqJcAYdvkD9qlIrgA+dM7vODPENpmoXsz7KmDZdrNJEn8r
e5BbUQ4etNTQxmbWaFTN4Q63Vnocj/dzCPL74IM8EzeLjGciK7oumxt+ljAfBzs=
-----END CERTIFICATE-----`;

function base64UrlEncode(str) {
  return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function arrayBufferToBase64Url(buffer) {
  const bytes = new Uint8Array(buffer);
  let binary = "";
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return base64UrlEncode(binary);
}

function extractPublicKeyFromCertificate(certPem) {
  const b64 = certPem
    .replace("-----BEGIN CERTIFICATE-----", "")
    .replace("-----END CERTIFICATE-----", "")
    .replace(/\s/g, "");

  const binary = atob(b64);

  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }

  for (let i = 0; i < bytes.length - 11; i++) {
    if (
      bytes[i] === 0x2a && // 42 (1.2)
      bytes[i + 1] === 0x86 && // 134 (840)
      bytes[i + 2] === 0x48 && // 72 (113549)
      bytes[i + 3] === 0x86 && // 134
      bytes[i + 4] === 0xf7 && // 247
      bytes[i + 5] === 0x0d && // 13
      bytes[i + 6] === 0x01 && // 1
      bytes[i + 7] === 0x01 && // 1
      bytes[i + 8] === 0x01
    ) {
      let pos = i - 2;
      while (pos > 0 && bytes[pos] !== 0x30) pos--;
      if (bytes[pos] !== 0x30) throw new Error("Sequence not found");

      pos++;
      let length = bytes[pos];
      if (length > 0x80) {
        const lengthBytes = length - 0x80;
        length = 0;
        for (let j = 0; j < lengthBytes; j++) {
          length = (length << 8) | bytes[pos + 1 + j];
        }
        pos += lengthBytes;
      }
      pos++;

      while (pos < bytes.length && bytes[pos] !== 0x03) pos++;
      if (bytes[pos] !== 0x03) throw new Error("Bit string not found");
      pos++;

      length = bytes[pos];
      if (length > 0x80) {
        const lengthBytes = length - 0x80;
        length = 0;
        for (let j = 0; j < lengthBytes; j++) {
          length = (length << 8) | bytes[pos + 1 + j];
        }
        pos += lengthBytes;
      }
      pos++;

      pos++;

      if (bytes[pos] !== 0x30) throw new Error("Key sequence not found");
      pos++;

      length = bytes[pos];
      if (length > 0x80) {
        const lengthBytes = length - 0x80;
        pos += lengthBytes + 1;
      } else {
        pos++;
      }

      if (bytes[pos] !== 0x02) throw new Error("Modulus not found");
      pos++;
      let modLength = bytes[pos];
      if (modLength > 0x80) {
        const lengthBytes = modLength - 0x80;
        modLength = 0;
        for (let j = 0; j < lengthBytes; j++) {
          modLength = (modLength << 8) | bytes[pos + 1 + j];
        }
        pos += lengthBytes + 1;
      } else {
        pos++;
      }

      if (bytes[pos] === 0x00) {
        pos++;
        modLength--;
      }

      const modulus = bytes.slice(pos, pos + modLength);
      pos += modLength;

      if (bytes[pos] !== 0x02) throw new Error("Exponent not found");
      pos++;
      let expLength = bytes[pos];
      pos++;
      const exponent = bytes.slice(pos, pos + expLength);

      return {
        modulus: Array.from(modulus),
        exponent: Array.from(exponent),
      };
    }
  }
  throw new Error("RSA public key not found");
}

async function importPublicKey(certPem) {
  try {
    const keyComponents = extractPublicKeyFromCertificate(certPem);

    // Create JWK from components
    const jwk = {
      kty: "RSA",
      n: arrayBufferToBase64Url(new Uint8Array(keyComponents.modulus)),
      e: arrayBufferToBase64Url(new Uint8Array(keyComponents.exponent)),
      alg: "RSA-OAEP-256",
      ext: true,
      key_ops: ["encrypt"],
    };

    // Import the JWK
    return await crypto.subtle.importKey(
      "jwk",
      jwk,
      {
        name: "RSA-OAEP",
        hash: { name: "SHA-256" },
      },
      false,
      ["encrypt"]
    );
  } catch (error) {
    throw error;
  }
}

export async function encryptMessage(payload) {
  // Convert JSON object back to string for encryption
  const input = JSON.stringify(payload);

  // Generate a random Content Encryption Key (CEK)
  const cek = await crypto.subtle.generateKey(
    { name: "AES-GCM", length: 256 },
    true,
    ["encrypt"]
  );

  // Generate random IV
  const iv = crypto.getRandomValues(new Uint8Array(12));

  // Create protected header with iat instead of cty
  const header = {
    alg: "RSA-OAEP-256",
    enc: "A256GCM",
    kid: keyId,
    iat: Math.floor(Date.now() / 1000), // Current timestamp in seconds
  };

  // Encode header
  const encodedHeader = base64UrlEncode(JSON.stringify(header));

  // Import public key and encrypt CEK
  const publicKey = await importPublicKey(certPem);
  const wrappedKey = await crypto.subtle.encrypt(
    {
      name: "RSA-OAEP",
    },
    publicKey,
    await crypto.subtle.exportKey("raw", cek)
  );

  // Encrypt the payload
  const encoder = new TextEncoder();
  const encodedPayload = encoder.encode(input);

  const encryptedData = await crypto.subtle.encrypt(
    {
      name: "AES-GCM",
      iv: iv,
      additionalData: encoder.encode(encodedHeader),
    },
    cek,
    encodedPayload
  );

  // Split encrypted data into ciphertext and authentication tag
  const encryptedContent = encryptedData.slice(0, -16);
  const authTag = encryptedData.slice(-16);

  // Construct JWE
  const jwe = [
    encodedHeader,
    arrayBufferToBase64Url(wrappedKey),
    arrayBufferToBase64Url(iv),
    arrayBufferToBase64Url(encryptedContent),
    arrayBufferToBase64Url(authTag),
  ].join(".");

  return jwe;
}
