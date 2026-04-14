import Link from "next/link";

export default function HomePage() {
  return (
    <main className="min-h-screen p-6">
      <div className="max-w-5xl mx-auto">
        <h1 className="text-2xl font-semibold mb-2">HeliosCTA Monitoring</h1>
        <p className="text-sm text-slate-400 mb-8">
          Postgres-direct dashboards. Every page reads live from{" "}
          <code className="text-slate-300">helioscta</code> at request time.
          No ingest layer.
        </p>

        <h2 className="text-xs uppercase tracking-wider text-slate-500 mb-3">
          Dashboards
        </h2>
        <ul className="space-y-2">
          <li>
            <Link
              href="/dashboards/clear-street-sftp"
              className="block rounded-md border border-slate-800 bg-slate-900 px-4 py-3 hover:border-slate-700 hover:bg-slate-800 transition-colors"
            >
              <div className="font-medium">Clear Street SFTP — last 7 days</div>
              <div className="text-xs text-slate-400 mt-0.5">
                When did each Clear Street EOD file land on SFTP, and when did
                we download it?
              </div>
            </Link>
          </li>
        </ul>

        <p className="text-xs text-slate-600 mt-12">
          Day 1 spike. See <code className="text-slate-500">frontend/README.md</code>.
        </p>
      </div>
    </main>
  );
}
