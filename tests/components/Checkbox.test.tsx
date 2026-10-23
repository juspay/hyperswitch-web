import React from "react";
import { atom, useAtom } from "jotai";
import { describe, expect, it } from "vitest";
import userEvent from "@testing-library/user-event";
import { make as Checkbox } from "../../src/Components/Checkbox.bs.js";
import { configAtom } from "../../src/Utilities/JotaiAtoms.bs.js";
import { initialValue, renderWithSdk, within } from "../helpers/render";

function BoundCheckbox({ checkedAtom }: { checkedAtom: ReturnType<typeof atom<boolean>> }) {
  const [checked, setChecked] = useAtom(checkedAtom);
  return <Checkbox label="Save card" isChecked={checked} onChange={setChecked}
    ariaLabelChecked="Card will be saved" ariaLabelUnchecked="Save this card" />;
}

describe("Checkbox", () => {
  it("updates real Jotai state on pointer and keyboard interaction", async () => {
    const user = userEvent.setup();
    const checkedAtom = atom(false);
    const view = renderWithSdk(<BoundCheckbox checkedAtom={checkedAtom} />);
    const checkbox = within(view.container).getByRole("checkbox", { name: "Save this card" });
    expect(checkbox).toHaveAttribute("aria-checked", "false");

    await user.click(within(view.container).getByText("Save card"));
    expect(view.store.get(checkedAtom)).toBe(true);
    expect(checkbox).toHaveAttribute("aria-checked", "true");
    expect(checkbox).toHaveAccessibleName("Card will be saved");

    checkbox.focus();
    await user.keyboard("{Enter}");
    expect(view.store.get(checkedAtom)).toBe(false);
    expect(checkbox).toHaveAttribute("aria-checked", "false");
  });

  it("uses a fresh store and independent configuration for every render", async () => {
    const user = userEvent.setup();
    const checkedAtom = atom(false);
    const first = renderWithSdk(<BoundCheckbox checkedAtom={checkedAtom} />,
      { initialValues: [initialValue(checkedAtom, true)] });
    const second = renderWithSdk(<BoundCheckbox checkedAtom={checkedAtom} />);
    expect(first.store).not.toBe(second.store);
    expect(first.store.get(configAtom)).not.toBe(second.store.get(configAtom));
    expect(first.store.get(configAtom).themeObj).not.toBe(second.store.get(configAtom).themeObj);
    expect(first.store.get(checkedAtom)).toBe(true);
    expect(second.store.get(checkedAtom)).toBe(false);
    await user.click(within(first.container).getByText("Save card"));
    expect(first.store.get(checkedAtom)).toBe(false);
    expect(second.store.get(checkedAtom)).toBe(false);
    await user.click(within(second.container).getByText("Save card"));
    expect(second.store.get(checkedAtom)).toBe(true);
    expect(first.store.get(checkedAtom)).toBe(false);
  });
});
