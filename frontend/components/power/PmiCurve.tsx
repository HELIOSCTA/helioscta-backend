"use client";

import { useEffect, useMemo, useState } from "react";
import {
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

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

const LOOKBACK_OPTIONS = [7, 14, 30, 60, 90];
const MAX_SNAPSHOT_LINES = 5;

const MONTH_ABBREV = [
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

const CHART_GRID_COLOR = "#1f2531";
const CHART_AXIS_COLOR = "#2b313d";
const CHART_TOOLTIP_BG = "#0d1119";
const CHART_TOOLTIP_BORDER = "#2b313d";

// Latest → oldest gradient (bright cyan → muted slate).
const SNAPSHOT_COLORS = ["#22d3ee", "#a78bfa", "#f59e0b", "#94a3b8", "#475569"];

function formatNum(n: number | null, digits = 2): string {
  return n === null
    ? "—"
    : n.toLocaleString(undefined, {
        minimumFractionDigits: digits,
        maximumFractionDigits: digits,
      });
}

function contractLabel(startDate: string): string {
  // "2026-05-01" -> "May-26"
  const month = parseInt(startDate.slice(5, 7), 10);
  const yy = startDate.slice(2, 4);
  return `${MONTH_ABBREV[month] ?? "?"}-${yy}`;
}

interface CurveRow {
  symbol: string;
  contract: string;
  strip: string | null;
  start_date: string;
  end_date: string;
  latest: SeriesPoint | null;
  prior: SeriesPoint | null;
}

interface ChartPoint {
  contract: string;
  [snapshotKey: string]: string | number | null;
}

interface SnapshotSeries {
  key: string;
  label: string;
  color: string;
}

function buildCurveRows(payload: PmiWidePayload): CurveRow[] {
  return payload.contracts.map((c) => {
    const series = c.series;
    const latest = series.length > 0 ? series[series.length - 1] : null;
    const prior = series.length > 1 ? series[0] : null;
    return {
      symbol: c.symbol,
      contract: contractLabel(c.start_date),
      strip: c.strip,
      start_date: c.start_date,
      end_date: c.end_date,
      latest,
      prior,
    };
  });
}

// Pick up to N snapshot trade_dates evenly distributed across the lookback
// window. Latest snapshot is always first; the rest sample backwards.
function pickSnapshotDates(payload: PmiWidePayload, maxLines: number): string[] {
  const all = new Set<string>();
  for (const c of payload.contracts) {
    for (const p of c.series) {
      if (p.settlement !== null) all.add(p.trade_date);
    }
  }
  const sorted = [...all].sort((a, b) => b.localeCompare(a)); // newest -> oldest
  if (sorted.length <= maxLines) return sorted;

  const picks: string[] = [sorted[0]];
  const step = (sorted.length - 1) / (maxLines - 1);
  for (let i = 1; i < maxLines; i++) {
    const idx = Math.round(i * step);
    picks.push(sorted[Math.min(idx, sorted.length - 1)]);
  }
  return picks;
}

function buildChartData(
  payload: PmiWidePayload,
  snapshotDates: string[]
): ChartPoint[] {
  return payload.contracts.map((c) => {
    const point: ChartPoint = { contract: contractLabel(c.start_date) };
    const byDate = new Map<string, number | null>();
    for (const p of c.series) byDate.set(p.trade_date, p.settlement);
    for (const d of snapshotDates) {
      point[d] = byDate.get(d) ?? null;
    }
    return point;
  });
}

export default function PmiCurve() {
  const [days, setDays] = useState(30);
  const [data, setData] = useState<PmiWidePayload | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [hiddenSnapshots, setHiddenSnapshots] = useState<Set<string>>(new Set());

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);
    fetch(`/api/pmi-wide?days=${days}`)
      .then((r) => {
        if (!r.ok) throw new Error(`HTTP ${r.status}`);
        return r.json();
      })
      .then((json: PmiWidePayload) => {
        if (!cancelled) {
          setData(json);
          setHiddenSnapshots(new Set());
        }
      })
      .catch((err: Error) => {
        if (!cancelled) setError(err.message);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [days]);

  const rows = useMemo(() => (data ? buildCurveRows(data) : []), [data]);

  const snapshotSeries = useMemo<SnapshotSeries[]>(() => {
    if (!data) return [];
    const dates = pickSnapshotDates(data, MAX_SNAPSHOT_LINES);
    return dates.map((d, i) => ({
      key: d,
      label: i === 0 ? `${d} (latest)` : d,
      color: SNAPSHOT_COLORS[i] ?? SNAPSHOT_COLORS[SNAPSHOT_COLORS.length - 1],
    }));
  }, [data]);

  const chartData = useMemo(() => {
    if (!data) return [];
    return buildChartData(
      data,
      snapshotSeries.map((s) => s.key)
    );
  }, [data, snapshotSeries]);

  const visibleSeries = snapshotSeries.filter((s) => !hiddenSnapshots.has(s.key));

  const toggleSnapshot = (key: string) => {
    setHiddenSnapshots((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  };

  return (
    <div className="space-y-4">
      {/* Lookback controls */}
      <div className="flex flex-wrap items-center gap-3">
        <span className="text-[10px] font-bold uppercase tracking-wider text-gray-500">
          Lookback
        </span>
        <div className="flex gap-1.5">
          {LOOKBACK_OPTIONS.map((d) => (
            <button
              key={d}
              onClick={() => setDays(d)}
              className={`rounded-md px-3 py-1.5 text-sm font-medium transition-colors ${
                days === d
                  ? "bg-gray-700 text-white"
                  : "border border-gray-800 text-gray-500 hover:bg-gray-800 hover:text-gray-300"
              }`}
            >
              {d}d
            </button>
          ))}
        </div>
        {data?.asOf && (
          <span className="ml-auto text-xs text-gray-500">
            As of {data.asOf.slice(0, 10)}
          </span>
        )}
      </div>

      {loading && <p className="text-sm text-gray-500">Loading PMI curve...</p>}
      {error && <p className="text-sm text-red-400">Failed to load: {error}</p>}

      {!loading && !error && rows.length === 0 && (
        <p className="text-sm text-gray-500">No active PMI contracts in range.</p>
      )}

      {/* Forward curve chart */}
      {!loading && !error && chartData.length > 0 && (
        <section className="rounded-lg border border-[#2b313d] bg-[#0d1119]">
          <div className="flex flex-wrap items-center justify-between gap-2 border-b border-[#2b313d] bg-[#171c27] px-3 py-2">
            <p className="text-[11px] font-bold uppercase tracking-widest text-white">
              PMI Forward Curve — Snapshots
            </p>
            <span className="text-[10px] font-semibold uppercase tracking-wider text-gray-300">
              Toggle snapshots in legend
            </span>
          </div>

          {visibleSeries.length > 0 ? (
            <div className="h-[320px] w-full p-3">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart
                  data={chartData}
                  margin={{ top: 8, right: 16, bottom: 8, left: -8 }}
                >
                  <CartesianGrid strokeDasharray="3 3" stroke={CHART_GRID_COLOR} />
                  <XAxis
                    dataKey="contract"
                    tick={{ fill: "#d1d5db", fontSize: 11 }}
                    stroke={CHART_AXIS_COLOR}
                  />
                  <YAxis
                    domain={["auto", "auto"]}
                    tick={{ fill: "#d1d5db", fontSize: 11 }}
                    stroke={CHART_AXIS_COLOR}
                    tickFormatter={(v: number) => v.toFixed(0)}
                  />
                  <Tooltip
                    contentStyle={{
                      backgroundColor: CHART_TOOLTIP_BG,
                      border: `1px solid ${CHART_TOOLTIP_BORDER}`,
                      borderRadius: 8,
                      fontSize: 12,
                    }}
                    formatter={(value) =>
                      typeof value === "number" ? value.toFixed(2) : "--"
                    }
                  />
                  {visibleSeries.map((line) => (
                    <Line
                      key={line.key}
                      type="monotone"
                      dataKey={line.key}
                      name={line.label}
                      stroke={line.color}
                      strokeWidth={line.key === snapshotSeries[0]?.key ? 2.5 : 1.5}
                      dot={false}
                      connectNulls
                    />
                  ))}
                </LineChart>
              </ResponsiveContainer>
            </div>
          ) : (
            <div className="px-3 py-6 text-sm text-gray-500">
              All snapshots hidden — toggle one on in the legend.
            </div>
          )}

          {/* Legend chips */}
          <div className="border-t border-[#2b313d] px-3 py-3">
            <div className="flex flex-wrap gap-1.5">
              {snapshotSeries.map((line) => {
                const isHidden = hiddenSnapshots.has(line.key);
                return (
                  <button
                    key={`curve-${line.key}`}
                    onClick={() => toggleSnapshot(line.key)}
                    className={`flex items-center gap-1.5 rounded border px-2 py-1 text-[10px] font-bold transition-colors ${
                      isHidden
                        ? "border-gray-700 bg-[#10141d] text-gray-500 hover:text-white"
                        : "border-gray-300/50 bg-[#1a1f2b] text-white"
                    }`}
                  >
                    <span
                      className="h-2 w-2 rounded-full"
                      style={{ backgroundColor: line.color, opacity: isHidden ? 0.3 : 1 }}
                    />
                    {line.label}
                  </button>
                );
              })}
            </div>
          </div>
        </section>
      )}

      {/* Active contracts table */}
      {!loading && !error && rows.length > 0 && (
        <section className="rounded-lg border border-[#2b313d] bg-[#0d1119]">
          <div className="flex flex-wrap items-center justify-between gap-2 border-b border-[#2b313d] bg-[#171c27] px-3 py-2">
            <p className="text-[11px] font-bold uppercase tracking-widest text-white">
              Active Contracts
            </p>
            <span className="text-[10px] font-semibold uppercase tracking-wider text-gray-300">
              Δ = latest settle − settle {days}d ago
            </span>
          </div>
          <div className="overflow-x-auto">
            <table className="min-w-full text-xs">
              <thead className="bg-[#171c27] text-[10px] uppercase tracking-wider text-gray-300">
                <tr>
                  <th className="px-3 py-2 text-left font-semibold">Contract</th>
                  <th className="px-3 py-2 text-left font-semibold">Symbol</th>
                  <th className="px-3 py-2 text-left font-semibold">Strip</th>
                  <th className="px-3 py-2 text-left font-semibold">Start</th>
                  <th className="px-3 py-2 text-left font-semibold">End</th>
                  <th className="px-3 py-2 text-right font-semibold">Settle</th>
                  <th className="px-3 py-2 text-right font-semibold">Δ vs {days}d</th>
                  <th className="px-3 py-2 text-right font-semibold">Volume</th>
                  <th className="px-3 py-2 text-right font-semibold">OI</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[#1f2531] text-gray-200">
                {rows.map((r) => {
                  const latestSettle = r.latest?.settlement ?? null;
                  const priorSettle = r.prior?.settlement ?? null;
                  const delta =
                    latestSettle !== null && priorSettle !== null
                      ? latestSettle - priorSettle
                      : null;
                  return (
                    <tr key={r.symbol} className="hover:bg-gray-800/40">
                      <td className="px-3 py-2 font-medium text-white">{r.contract}</td>
                      <td className="px-3 py-2 font-mono text-[11px] text-gray-400">
                        {r.symbol}
                      </td>
                      <td className="px-3 py-2">{r.strip ?? "—"}</td>
                      <td className="px-3 py-2 text-gray-500">{r.start_date}</td>
                      <td className="px-3 py-2 text-gray-500">{r.end_date}</td>
                      <td className="px-3 py-2 text-right font-medium">
                        {formatNum(latestSettle)}
                      </td>
                      <td
                        className={`px-3 py-2 text-right ${
                          delta === null
                            ? "text-gray-500"
                            : delta > 0
                              ? "text-emerald-400"
                              : delta < 0
                                ? "text-red-400"
                                : "text-gray-300"
                        }`}
                      >
                        {delta === null
                          ? "—"
                          : (delta > 0 ? "+" : "") + formatNum(delta)}
                      </td>
                      <td className="px-3 py-2 text-right text-gray-300">
                        {formatNum(r.latest?.volume ?? null, 0)}
                      </td>
                      <td className="px-3 py-2 text-right text-gray-300">
                        {formatNum(r.latest?.open_interest ?? null, 0)}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </section>
      )}
    </div>
  );
}
