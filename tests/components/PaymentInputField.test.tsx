import { sdkKeysAtom, sdkOptionsAtom } from "../helpers/sdk-atoms";
import React, { createRef, useState } from "react";
import { fireEvent, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import { make as PaymentInputField } from "../../src/Components/PaymentInputField.bs.js";
import { defaultOptions } from "../../src/Types/PaymentType.bs.js";
import { defaultkeys } from "../../src/Hooks/CommonHooks.bs.js";
import { initialValue, renderWithSdk } from "../helpers/render";

afterEach(() => vi.restoreAllMocks());

const props = () => ({
  value: "", onChange: vi.fn(), fieldName: "Cardholder name", name: "cardholder-name",
  inputRef: createRef(),
});

describe("PaymentInputField", () => {
  it("exposes its input label, displays errors, and allows hiding errors and labels", () => {
    const inputProps = { ...props(), value: "Jane", isValid: false, errorString: "Enter a full name" };
    const { rerender } = renderWithSdk(<PaymentInputField {...inputProps} />);
    expect(screen.getByRole("textbox", { name: "Type to fill Cardholder name input" })).toHaveValue("Jane");
    expect(screen.getByText("Cardholder name")).toBeInTheDocument();
    expect(screen.getByText("Enter a full name")).toBeVisible();
    rerender(<PaymentInputField {...inputProps} isLabelHidden isErrorHidden />);
    expect(screen.queryByText("Cardholder name")).not.toBeInTheDocument();
    expect(screen.queryByText("Enter a full name")).not.toBeInTheDocument();
  });

  it("updates through the caller's controlled onChange callback", async () => {
    vi.spyOn(window, "postMessage").mockImplementation(() => {});
    const changed = vi.fn();
    function ControlledInput() {
      const [value, setValue] = useState("");
      return <PaymentInputField {...props()} value={value} onChange={(event: React.ChangeEvent<HTMLInputElement>) => {
        changed(event.target.value);
        setValue(event.target.value);
      }} />;
    }
    renderWithSdk(<ControlledInput />);
    const input = screen.getByRole("textbox");
    await userEvent.setup().type(input, "Jane");
    expect(input).toHaveValue("Jane");
    expect(changed).toHaveBeenLastCalledWith("Jane");
  });

  it.each(["disabled prop", "read-only SDK option"])("blocks editing with %s", async scenario => {
    const inputProps = props();
    renderWithSdk(<PaymentInputField {...inputProps} isDisabled={scenario === "disabled prop"} />, {
      initialValues: [initialValue(sdkOptionsAtom, { ...defaultOptions, readOnly: scenario === "read-only SDK option" })],
    });
    const input = screen.getByRole("textbox");
    expect(input).toBeDisabled();
    await userEvent.setup().type(input, "Jane");
    expect(inputProps.onChange).not.toHaveBeenCalled();
    expect(input).toHaveValue("");
  });

  it("calls focus/blur handlers, clears validation, and posts scoped field messages", () => {
    const postMessage = vi.spyOn(window, "postMessage").mockImplementation(() => {});
    const onFocus = vi.fn();
    const onBlur = vi.fn();
    const setIsValid = vi.fn();
    renderWithSdk(<PaymentInputField {...props()} onFocus={onFocus} onBlur={onBlur} setIsValid={setIsValid} />, {
      paymentType: "CardNumberElement",
      initialValues: [initialValue(sdkKeysAtom, { ...defaultkeys, iframeId: "test-card-frame", parentURL: "https://merchant.example" })],
    });
    const input = screen.getByRole("textbox");
    fireEvent.focus(input);
    expect(onFocus).toHaveBeenCalledOnce();
    expect(setIsValid).toHaveBeenCalledOnce();
    expect(setIsValid.mock.calls[0][0](false)).toBeUndefined();
    expect(postMessage).toHaveBeenLastCalledWith({
      focus: true, elementType: "cardNumber", iframeId: "test-card-frame",
    }, "https://merchant.example");
    fireEvent.blur(input);
    expect(onBlur).toHaveBeenCalledOnce();
    expect(postMessage).toHaveBeenLastCalledWith({
      blur: true, elementType: "cardNumber", iframeId: "test-card-frame",
    }, "https://merchant.example");
  });
});
