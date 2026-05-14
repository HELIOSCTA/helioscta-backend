import { NextResponse } from "next/server";
import { query } from "@/lib/db";
import { buildContractSymbols, defaultCandidateYears } from "@/lib/iceSymbols";

export const dynamic = "force-dynamic";

const CACHE_TTL_MS = 5 * 60 * 1000;
const RESPONSE_CACHE = new Map<string, { expiresAt: number; payload: PmiWidePayload }>();

const DEFAULT_LOOKBACK_DAYS = 30;
const MIN_LOOKBACK_DAYS = 1;
const MAX_LOOKBACK_DAYS = 120;

interface ActiveContractRow {
  symbol: string;
  strip: string | null;
  start_date: string | Date;
  end_date: string | Date;
  updated_at: string | Date;
}

interface PivotedFuturesRow {
  symbol: string;
  trade_date: string | Date;
  settlement: string | number | null;
  volume: string | number | null;
  open_interest: string | number | null;
  futures_updated_at: string | Date | null;
}

interface SeriesPoint {
  trade_date: string;
  settlement: number | null;
  volume: number | null;
  open_interest: number | null;
}

interface ContractPayload {
  symbol: string;
  strip: string | null;
  start_date: string;
  end_date: string;
  contract_dates_updated_at: string;
  series: SeriesPoint[];
}

interface PmiWidePayload {
  asOf: string | null;
  lookbackDays: number;
  contracts: ContractPayload[];
}

// Two index-friendly queries. Each hits a covering index defined in
// backend/database/ice_python/{contract_dates,future_contracts}/*_indexes.sql.
//
//   Query 1: idx_contract_dates_sym_date  (symbol, trade_date DESC) INCLUDE (...)
//   Query 2: idx_fut_contracts_type_sym_date  (data_type, symbol, trade_date DESC) INCLUDE (value)
//
// Both predicates lead with `symbol = ANY($1)` (equality, not LIKE), which is
// what the indexes are built for. See defaultCandidateYears() for the symbol
// universe — DB filter `end_date >= current_date` is the authoritative cutoff.
const ACTIVE_SQL = `
  SELECT DISTINCT ON (symbol)
         symbol, strip, start_date, end_date, updated_at
  FROM ice_python.contract_dates
  WHERE symbol = ANY($1::text[])
    AND end_date >= current_date
  ORDER BY symbol, trade_date DESC
`;

const FUTURES_SQL = `
  SELECT symbol, trade_date,
         MAX(value) FILTER (WHERE data_type = 'Settlement')    AS settlement,
         MAX(value) FILTER (WHERE data_type = 'Volume')        AS volume,
         MAX(value) FILTER (WHERE data_type = 'Open Interest') AS open_interest,
         MAX(updated_at)                                       AS futures_updated_at
  FROM ice_python.future_contracts_v1_2025_dec_16
  WHERE symbol = ANY($1::text[])
    AND data_type IN ('Settlement', 'Volume', 'Open Interest')
    AND trade_date >= current_date - $2::int
  GROUP BY symbol, trade_date
  ORDER BY symbol, trade_date
`;

function toNumber(value: unknown): number | null {
  if (value === null || value === undefined) return null;
  const n = typeof value === "number" ? value : Number(value);
  return Number.isFinite(n) ? n : null;
}

function toDateKey(value: string | Date): string {
  if (value instanceof Date) return value.toISOString().slice(0, 10);
  return value.length >= 10 ? value.slice(0, 10) : new Date(value).toISOString().slice(0, 10);
}

function parseLookbackDays(raw: string | null): number {
  if (!raw) return DEFAULT_LOOKBACK_DAYS;
  const n = Number.parseInt(raw, 10);
  if (!Number.isFinite(n)) return DEFAULT_LOOKBACK_DAYS;
  return Math.min(MAX_LOOKBACK_DAYS, Math.max(MIN_LOOKBACK_DAYS, n));
}

function buildPayload(
  activeRows: ActiveContractRow[],
  futuresRows: PivotedFuturesRow[],
  lookbackDays: number
): PmiWidePayload {
  const contracts = new Map<string, ContractPayload>();
  for (const row of activeRows) {
    contracts.set(row.symbol, {
      symbol: row.symbol,
      strip: row.strip,
      start_date: toDateKey(row.start_date),
      end_date: toDateKey(row.end_date),
      contract_dates_updated_at:
        row.updated_at instanceof Date ? row.updated_at.toISOString() : String(row.updated_at),
      series: [],
    });
  }

  let asOf: string | null = null;
  for (const row of futuresRows) {
    const contract = contracts.get(row.symbol);
    if (!contract) continue;
    contract.series.push({
      trade_date: toDateKey(row.trade_date),
      settlement: toNumber(row.settlement),
      volume: toNumber(row.volume),
      open_interest: toNumber(row.open_interest),
    });
    if (row.futures_updated_at) {
      const stamp =
        row.futures_updated_at instanceof Date
          ? row.futures_updated_at.toISOString()
          : String(row.futures_updated_at);
      if (!asOf || stamp > asOf) asOf = stamp;
    }
  }

  const ordered = [...contracts.values()].sort((a, b) =>
    a.start_date.localeCompare(b.start_date)
  );

  return { asOf, lookbackDays, contracts: ordered };
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const lookbackDays = parseLookbackDays(searchParams.get("days"));

  const cacheKey = `pmi-wide:${lookbackDays}`;
  const cached = RESPONSE_CACHE.get(cacheKey);
  if (cached && cached.expiresAt > Date.now()) {
    return NextResponse.json(cached.payload, {
      headers: { "Cache-Control": "public, s-maxage=300, stale-while-revalidate=60" },
    });
  }

  try {
    const candidateSymbols = buildContractSymbols(["PMI"], defaultCandidateYears());

    const activeResult = await query<ActiveContractRow>(ACTIVE_SQL, [candidateSymbols]);
    if (activeResult.rows.length === 0) {
      const payload: PmiWidePayload = { asOf: null, lookbackDays, contracts: [] };
      return NextResponse.json(payload, {
        headers: { "Cache-Control": "public, s-maxage=300, stale-while-revalidate=60" },
      });
    }

    const activeSymbols = activeResult.rows.map((r) => r.symbol);
    const futuresResult = await query<PivotedFuturesRow>(FUTURES_SQL, [
      activeSymbols,
      lookbackDays,
    ]);

    const payload = buildPayload(activeResult.rows, futuresResult.rows, lookbackDays);

    RESPONSE_CACHE.set(cacheKey, { expiresAt: Date.now() + CACHE_TTL_MS, payload });

    return NextResponse.json(payload, {
      headers: { "Cache-Control": "public, s-maxage=300, stale-while-revalidate=60" },
    });
  } catch (error) {
    console.error("[pmi-wide] DB query failed:", error);
    return NextResponse.json(
      { error: "Failed to fetch PMI wide data" },
      { status: 500 }
    );
  }
}
