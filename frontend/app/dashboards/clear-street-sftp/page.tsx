import Link from "next/link";
import { sql } from "@/lib/db";

// Force this page to be dynamically rendered on every request, with no
// caching. Otherwise Next.js may statically prerender it at build time and
// serve a stale snapshot. We want a fresh Postgres query every page load.
export const dynamic = "force-dynamic";
export const revalidate = 0;

interface SftpRow {
  trade_date_raw: string; // ISO date — used only for sorting, not displayed
  trade_date: string;
  released_from_clear_street: string;
  downloaded_at: string;
}

async function fetchRows(): Promise<{ rows: SftpRow[]; error: string | null }> {
  try {
    // Adapted from .sql_queries/check_clear_street_sftp.sql.
    //
    // The raw date column is included in the SELECT list specifically so it
    // can drive ORDER BY — Postgres requires ORDER BY expressions to appear
    // in the select list when DISTINCT is used. The display column is the
    // pre-formatted to_char() string, sorted chronologically by the raw date
    // (sorting by the formatted "Dy Mon-DD" alphabetically would put
    // "Mon Apr-08" before "Tue Apr-09" — wrong).
    const rows = await sql<SftpRow>`
      SELECT DISTINCT
          trade_date_from_sftp::DATE                                 AS trade_date_raw,
          to_char(trade_date_from_sftp::DATE, 'Dy Mon-DD')           AS trade_date,
          to_char(sftp_upload_timestamp, 'Dy Mon-DD HH12:MI AM')     AS released_from_clear_street,
          to_char(created_at, 'Dy Mon-DD HH12:MI AM')                AS downloaded_at
      FROM clear_street.helios_transactions_v2_2026_feb_23
      WHERE trade_date_from_sftp::DATE >= current_date - 7
      ORDER BY trade_date_raw DESC
    `;
    return { rows, error: null };
  } catch (e) {
    return { rows: [], error: e instanceof Error ? e.message : String(e) };
  }
}

export default async function ClearStreetSftpPage() {
  const { rows, error } = await fetchRows();
  const renderedAt = new Date().toISOString();

  return (
    <main className="min-h-screen p-6">
      <div className="max-w-5xl mx-auto">
        <div className="mb-6">
          <Link
            href="/"
            className="text-xs text-slate-500 hover:text-slate-300 transition-colors"
          >
            ← Dashboards
          </Link>
        </div>

        <h1 className="text-2xl font-semibold mb-2">
          Clear Street SFTP — last 7 days
        </h1>
        <p className="text-sm text-slate-400 mb-6">
          Live query against{" "}
          <code className="text-slate-300">
            clear_street.helios_transactions_v2_2026_feb_23
          </code>
          . Rendered server-side at request time.
        </p>

        {error ? (
          <div className="rounded-md border border-red-500/40 bg-red-950/40 p-4 text-sm">
            <div className="font-semibold text-red-300 mb-2">Query failed</div>
            <pre className="text-red-200 whitespace-pre-wrap text-xs">
              {error}
            </pre>
            <div className="text-xs text-red-300/70 mt-3">
              If this is a connection error (ENOTFOUND, ECONNREFUSED, auth
              failed): check the <code>AZURE_POSTGRESQL_DB_*</code> env vars in{" "}
              <code>frontend/.env.local</code> and restart{" "}
              <code>npm run dev</code>. If it&apos;s a SQL error: the message
              above is the verbatim Postgres response.
            </div>
          </div>
        ) : rows.length === 0 ? (
          <div className="rounded-md border border-slate-800 bg-slate-900 p-6 text-sm text-slate-400">
            No rows returned. Either the SFTP table is empty for the last 7
            days, or you are pointed at the wrong database. Verify with the
            same SQL in pgAdmin / DBeaver.
          </div>
        ) : (
          <div className="rounded-md border border-slate-800 bg-slate-900 overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-slate-900/60 border-b border-slate-800">
                <tr>
                  <th className="text-left px-4 py-3 font-medium text-slate-300">
                    Trade Date
                  </th>
                  <th className="text-left px-4 py-3 font-medium text-slate-300">
                    Released from Clear Street
                  </th>
                  <th className="text-left px-4 py-3 font-medium text-slate-300">
                    Downloaded
                  </th>
                </tr>
              </thead>
              <tbody>
                {rows.map((row, i) => (
                  <tr
                    key={`${row.trade_date}-${i}`}
                    className={
                      i % 2
                        ? "bg-slate-900 border-t border-slate-800/60"
                        : "bg-slate-900/40 border-t border-slate-800/60"
                    }
                  >
                    <td className="px-4 py-2.5 text-slate-100">
                      {row.trade_date}
                    </td>
                    <td className="px-4 py-2.5 text-slate-300 tabular-nums">
                      {row.released_from_clear_street}
                    </td>
                    <td className="px-4 py-2.5 text-slate-300 tabular-nums">
                      {row.downloaded_at}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        <p className="text-xs text-slate-600 mt-6">
          {rows.length} row{rows.length === 1 ? "" : "s"} · rendered at{" "}
          <span className="tabular-nums">{renderedAt}</span>
        </p>
      </div>
    </main>
  );
}
