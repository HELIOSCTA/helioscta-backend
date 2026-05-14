// ICE futures symbol helpers.
//
// ICE symbol grammar: `<root> <strip><yy>-IUS` (e.g. "PMI K26-IUS" = May 2026 PJM).
// The DB indexes are tuned for equality predicates (symbol = ANY($1::text[])),
// not prefix LIKE, so callers should pre-build a candidate symbol list and
// bind it as ANY() rather than `symbol LIKE '<root> %-IUS'`.

export const STRIP_TO_MONTH: Record<string, number> = {
  F: 1,
  G: 2,
  H: 3,
  J: 4,
  K: 5,
  M: 6,
  N: 7,
  Q: 8,
  U: 9,
  V: 10,
  X: 11,
  Z: 12,
};

export const MONTH_TO_STRIP: Record<number, string> = Object.fromEntries(
  Object.entries(STRIP_TO_MONTH).map(([s, m]) => [m, s])
);

export const MONTH_NAMES = [
  "",
  "Jan",
  "Feb",
  "Mar",
  "Apr",
  "May",
  "Jun",
  "Jul",
  "Aug",
  "Sep",
  "Oct",
  "Nov",
  "Dec",
];

export interface ParsedSymbol {
  root: string;
  stripCode: string;
  month: number;
  year: number;
}

const SYMBOL_RE = /^([A-Z]+)\s+([A-Z])(\d{2})-IUS$/;

export function parseSymbol(symbol: string): ParsedSymbol | null {
  const match = symbol.match(SYMBOL_RE);
  if (!match) return null;
  const [, root, stripCode, yearSuffix] = match;
  const month = STRIP_TO_MONTH[stripCode];
  if (!month) return null;
  return { root, stripCode, month, year: 2000 + parseInt(yearSuffix, 10) };
}

// Build every `<root> <strip><yy>-IUS` symbol for the given roots and years.
// Returns a candidate superset; callers should still filter by contract_dates
// (end_date >= current_date) to drop expired strips.
export function buildContractSymbols(roots: string[], years: number[]): string[] {
  const out: string[] = [];
  for (const root of roots) {
    for (const year of years) {
      const yy = String(year % 100).padStart(2, "0");
      for (let month = 1; month <= 12; month++) {
        out.push(`${root} ${MONTH_TO_STRIP[month]}${yy}-IUS`);
      }
    }
  }
  return out;
}

// Default candidate window: previous year through three years ahead.
// Wide enough that the DB's `end_date >= current_date` filter is the
// authoritative cutoff, not this helper.
export function defaultCandidateYears(): number[] {
  const current = new Date().getFullYear();
  return [current - 1, current, current + 1, current + 2, current + 3];
}
