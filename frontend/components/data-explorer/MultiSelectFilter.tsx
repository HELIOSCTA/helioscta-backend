"use client";

import { useEffect, useRef, useState } from "react";

interface MultiSelectFilterProps {
  label: string;
  options: string[];
  selected: Set<string>;
  onChange: (next: Set<string>) => void;
  disabled?: boolean;
  placeholder?: string;
  /** Format option labels for display (default: identity) */
  formatLabel?: (value: string) => string;
}

export default function MultiSelectFilter({
  label,
  options,
  selected,
  onChange,
  disabled = false,
  placeholder,
  formatLabel,
}: MultiSelectFilterProps) {
  const [open, setOpen] = useState(false);
  const [search, setSearch] = useState("");
  const ref = useRef<HTMLDivElement>(null);

  // Close dropdown on outside click
  useEffect(() => {
    if (!open) return;
    const handler = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false);
      }
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, [open]);

  const filtered = search
    ? options.filter((o) =>
        o.toLowerCase().includes(search.toLowerCase()),
      )
    : options;

  const toggle = (value: string) => {
    const next = new Set(selected);
    if (next.has(value)) next.delete(value);
    else next.add(value);
    onChange(next);
  };

  const selectAll = () => onChange(new Set(filtered));

  const clear = () => {
    onChange(new Set());
    setSearch("");
  };

  const display = (value: string) =>
    formatLabel ? formatLabel(value) : value;

  const buttonText =
    selected.size === 0
      ? placeholder ?? label
      : selected.size === 1
        ? display(Array.from(selected)[0])
        : `${selected.size} selected`;

  return (
    <div ref={ref} className="relative">
      <button
        type="button"
        onClick={() => !disabled && setOpen(!open)}
        disabled={disabled}
        className={`flex items-center gap-1.5 rounded-md border px-3 py-1.5 text-xs font-medium transition-colors ${
          disabled
            ? "cursor-not-allowed border-gray-800 bg-gray-900/50 text-gray-600"
            : selected.size > 0
              ? "border-blue-500/50 bg-blue-600/20 text-blue-300"
              : "border-gray-700 bg-gray-800 text-gray-400 hover:text-gray-200"
        }`}
      >
        <span className="max-w-[160px] truncate">{buttonText}</span>
        <svg
          className={`h-3 w-3 transition-transform ${open ? "rotate-180" : ""}`}
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          strokeWidth={2}
        >
          <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      {open && !disabled && (
        <div className="absolute left-0 z-50 mt-1 w-64 rounded-lg border border-gray-700 bg-[#111827] shadow-xl">
          {/* Search */}
          <div className="border-b border-gray-700 p-2">
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder={`Search ${label.toLowerCase()}...`}
              className="w-full rounded border border-gray-700 bg-gray-800 px-2 py-1 text-xs text-gray-200 placeholder-gray-500 outline-none focus:border-blue-500"
              autoFocus
            />
          </div>

          {/* Select all / Clear actions */}
          <div className="flex items-center justify-between border-b border-gray-700/60 px-3 py-1.5">
            <button
              type="button"
              onClick={selectAll}
              className="text-[11px] text-blue-400 hover:text-blue-300"
            >
              Select all ({filtered.length})
            </button>
            {selected.size > 0 && (
              <button
                type="button"
                onClick={clear}
                className="text-[11px] text-gray-400 hover:text-gray-200"
              >
                Clear
              </button>
            )}
          </div>

          {/* Option list */}
          <div className="max-h-56 overflow-y-auto p-1">
            {filtered.length === 0 ? (
              <p className="px-2 py-3 text-center text-xs text-gray-500">
                No matches
              </p>
            ) : (
              filtered.map((option) => (
                <label
                  key={option}
                  className="flex cursor-pointer items-center gap-2 rounded px-2 py-1 text-xs text-gray-300 hover:bg-gray-800"
                >
                  <input
                    type="checkbox"
                    checked={selected.has(option)}
                    onChange={() => toggle(option)}
                    className="h-3 w-3 rounded border-gray-600 bg-gray-700 accent-blue-500"
                  />
                  <span className="truncate">{display(option)}</span>
                </label>
              ))
            )}
          </div>
        </div>
      )}
    </div>
  );
}
