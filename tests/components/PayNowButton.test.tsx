import { sdkOptionsAtom } from "../helpers/sdk-atoms";
import React from "react";
import { fireEvent, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import { make as PayNowButton } from "../../src/Components/PayNowButton.bs.js";
import { defaultOptions } from "../../src/Types/PaymentType.bs.js";
import { removeSmartEventListener } from "../../src/Utilities/EventListenerManager.bs.js";
import { initialValue, renderWithSdk } from "../helpers/render";

afterEach(() => {
  removeSmartEventListener("message", "onSubmitSuccessful");
  vi.restoreAllMocks();
});

const configuredOptions = {
  ...defaultOptions,
  sdkHandleConfirmPayment: {
    ...defaultOptions.sdkHandleConfirmPayment, buttonText: "Pay securely",
    confirmParams: { ...defaultOptions.sdkHandleConfirmPayment.confirmParams, return_url: "https://merchant.example/done" },
  },
  sdkHandleSavePayment: { ...defaultOptions.sdkHandleSavePayment, buttonText: "Save this card" },
};

describe("PayNowButton", () => {
  it("uses the configured payment label and gives an explicit label priority", () => {
    const { rerender } = renderWithSdk(<PayNowButton />, { initialValues: [initialValue(sdkOptionsAtom, configuredOptions)] });
    expect(screen.getByRole("button", { name: "Pay securely" })).toBeEnabled();
    rerender(<PayNowButton label="Complete purchase" />);
    expect(screen.getByRole("button", { name: "Complete purchase" })).toBeEnabled();
  });

  it("uses the save label in payment-method management context", () => {
    renderWithSdk(<PayNowButton label="Payment label" />, {
      paymentType: "PaymentMethodsManagement", initialValues: [initialValue(sdkOptionsAtom, configuredOptions)],
    });
    expect(screen.getByRole("button", { name: "Save this card" })).toBeEnabled();
  });

  it("invokes a custom callback without starting SDK submission", async () => {
    const callback = vi.fn();
    const postMessage = vi.spyOn(window, "postMessage").mockImplementation(() => {});
    renderWithSdk(<PayNowButton label="Custom payment" onClickHandler={callback} />);
    const button = screen.getByRole("button", { name: "Custom payment" });
    await userEvent.setup().click(button);
    expect(callback).toHaveBeenCalledOnce();
    expect(button).toBeEnabled();
    expect(button).toHaveTextContent("Custom payment");
    expect(postMessage).not.toHaveBeenCalled();
  });

  it("disables and loads during submission, then recovers after an unsuccessful response", async () => {
    const postMessage = vi.spyOn(window, "postMessage").mockImplementation(() => {});
    renderWithSdk(<PayNowButton />, { initialValues: [initialValue(sdkOptionsAtom, configuredOptions)] });
    const button = screen.getByRole("button", { name: "Pay securely" });
    await userEvent.setup().click(button);
    expect(button).toBeDisabled();
    expect(button).not.toHaveTextContent("Pay securely");
    expect(button.querySelector(".animate-spin")).toBeInTheDocument();
    expect(postMessage).toHaveBeenCalledWith({ handleSdkConfirm: {
      confirmParams: { return_url: "https://merchant.example/done", redirect: "always" },
    } }, "*");
    fireEvent(window, new MessageEvent("message", { data: JSON.stringify({ unrelated: true }) }));
    expect(button).toBeDisabled();
    fireEvent(window, new MessageEvent("message", { data: JSON.stringify({ submitSuccessful: true }) }));
    expect(button).toBeDisabled();
    fireEvent(window, new MessageEvent("message", { data: JSON.stringify({ submitSuccessful: false }) }));
    expect(button).toBeEnabled();
    expect(button).toHaveTextContent("Pay securely");
    expect(button.querySelector(".animate-spin")).not.toBeInTheDocument();
    await userEvent.setup().click(button);
    expect(postMessage).toHaveBeenCalledTimes(2);
  });
});
