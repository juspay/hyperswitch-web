import React, { useState } from "react";
import { describe, expect, it, vi } from "vitest";
import { act, fireEvent, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

// These intentionally run as separate tests: teardown between scenarios must
// remove fixture resources without removing React/user-event document hooks.
describe("DOM setup isolation", () => {
  it.each(["first root", "root after test cleanup"])("preserves controlled typing for %s", async () => {
    const onChange = vi.fn();
    function ControlledInput() {
      const [value, setValue] = useState("");
      return <input aria-label="Typing fixture" value={value} onChange={event => {
        onChange(event.target.value);
        setValue(event.target.value);
      }} />;
    }
    render(<ControlledInput />);
    const input = screen.getByRole("textbox", { name: "Typing fixture" });
    await userEvent.setup().type(input, "Jane");
    expect(input).toHaveValue("Jane");
    expect(onChange).toHaveBeenLastCalledWith("Jane");
    expect(onChange).toHaveBeenCalledTimes(4);
  });

  it.each(["first root", "root after test cleanup"])("preserves selection events for %s", () => {
    const onSelect = vi.fn();
    render(<input aria-label="Selection fixture" defaultValue="sample" onSelect={onSelect} />);
    const input = screen.getByRole("textbox", { name: "Selection fixture" });
    act(() => input.focus());
    onSelect.mockClear();
    (input as HTMLInputElement).setSelectionRange(1, 3);
    fireEvent(document, new Event("selectionchange"));
    expect(onSelect).toHaveBeenCalledOnce();
  });
});
