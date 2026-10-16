import React, { useRef } from "react";
import { act, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { useOutsideClick } from "../../src/Hooks/OutsideClick.bs.js";

function Harness({ active = true, callback, contained = false }: { active?: boolean; callback: () => void; contained?: boolean }) {
  const insideRef = useRef(null);
  const containerRef = useRef(null);
  useOutsideClick({ TAG: "ArrayOfRef", _0: [insideRef] }, contained ? containerRef : undefined, active, undefined, callback);
  return <div ref={containerRef}>
    <div ref={insideRef}><button>Inside</button></div>
    <button>Outside</button>
  </div>;
}

beforeEach(() => vi.useFakeTimers());
afterEach(() => {
  vi.clearAllTimers();
  vi.useRealTimers();
});
const register = () => act(() => vi.advanceTimersByTime(50));

describe("OutsideClick", () => {
  it("ignores inside clicks and invokes its callback for outside clicks", () => {
    const callback = vi.fn();
    const { unmount } = render(<Harness callback={callback} />);
    fireEvent.click(screen.getByText("Outside"));
    expect(callback).not.toHaveBeenCalled();
    register();
    fireEvent.click(screen.getByText("Inside"));
    expect(callback).not.toHaveBeenCalled();
    fireEvent.click(screen.getByText("Outside"));
    expect(callback).toHaveBeenCalledOnce();
    unmount();
    fireEvent.click(document.body);
    expect(callback).toHaveBeenCalledOnce();
  });

  it("does not register while inactive and removes listeners when deactivated", () => {
    const callback = vi.fn();
    const { rerender } = render(<Harness active={false} callback={callback} />);
    register();
    fireEvent.click(document.body);
    expect(callback).not.toHaveBeenCalled();
    rerender(<Harness callback={callback} />);
    register();
    fireEvent.click(document.body);
    expect(callback).toHaveBeenCalledOnce();
    rerender(<Harness active={false} callback={callback} />);
    fireEvent.click(document.body);
    expect(callback).toHaveBeenCalledOnce();
  });

  it("uses the latest callback after rerender", () => {
    const previous = vi.fn();
    const latest = vi.fn();
    const { rerender } = render(<Harness callback={previous} />);
    register();
    rerender(<Harness callback={latest} />);
    fireEvent.click(document.body);
    expect(previous).not.toHaveBeenCalled();
    expect(latest).toHaveBeenCalledOnce();
  });

  it("limits outside clicks to the optional container", () => {
    const callback = vi.fn();
    render(<Harness callback={callback} contained />);
    register();
    fireEvent.click(document.body);
    expect(callback).not.toHaveBeenCalled();
    fireEvent.click(screen.getByText("Outside"));
    expect(callback).toHaveBeenCalledOnce();
  });

  it("cancels delayed listener registration when unmounted before 50ms", () => {
    const callback = vi.fn();
    const { unmount } = render(<Harness callback={callback} />);
    unmount();
    register();
    fireEvent.click(document.body);
    expect(callback).not.toHaveBeenCalled();
  });
});
