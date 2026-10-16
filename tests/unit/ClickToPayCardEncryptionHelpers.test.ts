import { parseJson } from "../helpers/json";
import { webcrypto } from "node:crypto";
import { beforeAll, describe, expect, it, vi } from "vitest";
let keys: webcrypto.CryptoKeyPair;
let certificate: string;
beforeAll(async () => {
  keys = await webcrypto.subtle.generateKey({
    name: "RSA-OAEP",
    modulusLength: 2048,
    publicExponent: new Uint8Array([1, 0, 1]),
    hash: "SHA-256"
  }, true, ["encrypt", "decrypt"]);
  // Synthetic test material: this parser locates the RSA SPKI sequence inside
  // PEM certificate bytes. No production certificate or external service is used.
  const spki = await webcrypto.subtle.exportKey("spki", keys.publicKey);
  certificate = `-----BEGIN CERTIFICATE-----\n${Buffer.from(spki).toString("base64")}\n-----END CERTIFICATE-----`;
});
async function encryptor(pem = certificate) {
  vi.stubGlobal("crypto", webcrypto);
  vi.stubGlobal("visaAPIKeyId", "unit-key-id");
  vi.stubGlobal("visaAPICertificatePem", pem);
  vi.resetModules();
  return (await import("../../src/Utilities/ClickToPayCardEncryptionHelpers.js")).encryptMessage;
}
const decode = (part: string) => Buffer.from(part, "base64url");
describe("ClickToPay real WebCrypto encryption", () => {
  it("encrypts a compact JWE that decrypts to the payload and authenticates its header", async () => {
    const encrypt = await encryptor();
    const payload = {
      cardNumber: "4111111111111111",
      securityCode: "123",
      name: "Synthetic Cardholder"
    };
    const before = Math.floor(Date.now() / 1000);
    const jwe = await encrypt(payload);
    const [header, wrapped, iv, ciphertext, tag] = jwe.split(".");
    expect(jwe.split(".")).toHaveLength(5);
    expect(jwe).toMatch(/^[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+){4}$/);
    const metadata = parseJson(decode(header).toString()) as { iat: number };
    expect(metadata).toMatchObject({
      alg: "RSA-OAEP-256",
      enc: "A256GCM",
      kid: "unit-key-id"
    });
    expect(metadata.iat).toBeGreaterThanOrEqual(before);
    expect(metadata.iat).toBeLessThanOrEqual(Math.floor(Date.now() / 1000));
    expect(decode(iv)).toHaveLength(12);
    expect(decode(tag)).toHaveLength(16);
    const rawKey = await webcrypto.subtle.decrypt({
      name: "RSA-OAEP"
    }, keys.privateKey, decode(wrapped));
    const cek = await webcrypto.subtle.importKey("raw", rawKey, "AES-GCM", false, ["decrypt"]);
    const encrypted = Buffer.concat([decode(ciphertext), decode(tag)]);
    const result = await webcrypto.subtle.decrypt({
      name: "AES-GCM",
      iv: decode(iv),
      additionalData: Buffer.from(header)
    }, cek, encrypted);
    expect(parseJson(Buffer.from(result).toString())).toEqual(payload);
    expect(payload.securityCode).toBe("123");
    await expect(webcrypto.subtle.decrypt({
      name: "AES-GCM",
      iv: decode(iv),
      additionalData: Buffer.from(`${header}x`)
    }, cek, encrypted)).rejects.toThrow();
    const another = await encrypt(payload);
    expect(another).not.toBe(jwe);
  });
  it.each(["%%%", "-----BEGIN CERTIFICATE-----AA==-----END CERTIFICATE-----"])("rejects invalid certificate bytes: %s", async pem => {
    await expect((await encryptor(pem))({
      cardNumber: "4111111111111111"
    })).rejects.toThrow();
  });
  it("propagates crypto failures and serialization failures as rejected promises", async () => {
    const encrypt = await encryptor();
    const error = new Error("synthetic crypto rejection");
    vi.spyOn(webcrypto.subtle, "generateKey").mockRejectedValueOnce(error);
    await expect(encrypt({})).rejects.toBe(error);
    const cyclic: { self?: unknown } = {};
    cyclic.self = cyclic;
    await expect(encrypt(cyclic)).rejects.toThrow(/circular/i);
  });
  it.each(["importKey", "exportKey", "encrypt"] as const)("propagates the %s rejection without returning partial ciphertext", async method => {
    const encrypt = await encryptor();
    const error = new Error(`synthetic ${method} rejection`);
    vi.spyOn(webcrypto.subtle, method).mockRejectedValueOnce(error);
    await expect(encrypt({
      cardNumber: "4111111111111111"
    })).rejects.toBe(error);
  });
});
