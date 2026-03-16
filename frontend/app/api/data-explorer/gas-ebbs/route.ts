import { NextResponse } from "next/server";
import { query } from "@/lib/db";
import type {
  GasEbbDashboardResponse,
  GasEbbTimingState,
} from "@/lib/dataExplorerTypes";

const CLOSED_NOTICE_SUBJECT_REGEX =
  "(lifted|cancel|cancell|complete|completed|terminate|terminated)";
const OPEN_ENDED_RECENCY_DAYS = 14;
const TIMELINE_RECENT_ENDED_DAYS = 7;

function parseTimestampSql(column: string): string {
  return `
    CASE
      -- ISO 8601: 2025-12-04T15:15:22.632 (bhegts)
      WHEN ${column} ~ '^\\d{4}-\\d{2}-\\d{2}T'
        THEN regexp_replace(${column}, '\\.\\d+$', '')::timestamp
      -- MM/DD/YYYY HH:MM:SS AM/PM (enbridge, kindermorgan)
      WHEN ${column} ~ '^\\d{2}/\\d{2}/\\d{4}\\s+\\d{1,2}:\\d{2}:\\d{2}\\s?(AM|PM)$'
        THEN to_timestamp(regexp_replace(${column}, '\\s*(AM|PM)$', ' \\1'), 'MM/DD/YYYY HH12:MI:SS AM')
      -- MM/DD/YY HH:MM:SS AM/PM
      WHEN ${column} ~ '^\\d{2}/\\d{2}/\\d{2}\\s+\\d{1,2}:\\d{2}:\\d{2}\\s?(AM|PM)$'
        THEN to_timestamp(regexp_replace(${column}, '\\s*(AM|PM)$', ' \\1'), 'MM/DD/YY HH12:MI:SS AM')
      -- MM/DD/YYYY HH:MM:SS TZ — 24h with 3-4 char timezone abbrev (williams)
      WHEN ${column} ~ '^\\d{2}/\\d{2}/\\d{4}\\s+\\d{2}:\\d{2}:\\d{2}\\s+[A-Z]{3,4}$'
        THEN to_timestamp(regexp_replace(${column}, '\\s+[A-Z]{3,4}$', ''), 'MM/DD/YYYY HH24:MI:SS')
      -- Mon DD, YYYY HH:MM:SS AM/PM (gasnom)
      WHEN ${column} ~ '^[A-Z][a-z]{2}\\s+\\d{1,2},\\s*\\d{4}\\s+\\d{1,2}:\\d{2}:\\d{2}\\s?(AM|PM)$'
        THEN to_timestamp(regexp_replace(${column}, '\\s*(AM|PM)$', ' \\1'), 'Mon DD, YYYY HH12:MI:SS AM')
      -- Mon DD YYYY H:MM AM/PM — no comma (northern_natural)
      WHEN ${column} ~ '^[A-Z][a-z]{2}\\s+\\d{1,2}\\s+\\d{4}\\s+\\d{1,2}:\\d{2}\\s?(AM|PM)$'
        THEN to_timestamp(regexp_replace(${column}, '\\s*(AM|PM)$', ' \\1'), 'Mon DD YYYY HH12:MI AM')
      -- MM/DD/YYYY (date only)
      WHEN ${column} ~ '^\\d{2}/\\d{2}/\\d{4}$'
        THEN to_date(${column}, 'MM/DD/YYYY')::timestamp
      -- MM/DD/YY (date only)
      WHEN ${column} ~ '^\\d{2}/\\d{2}/\\d{2}$'
        THEN to_date(${column}, 'MM/DD/YY')::timestamp
      ELSE NULL
    END
  `;
}

const normalizedNoticesCte = `
  WITH normalized_notices AS (
    SELECT
      source_family,
      pipeline_name,
      notice_identifier,
      notice_type,
      notice_subtype,
      subject,
      notice_status,
      posted_datetime,
      effective_datetime,
      end_datetime,
      response_datetime,
      detail_url,
      notice_category,
      severity,
      scraped_at,
      scraped_at::timestamptz AS scraped_at_ts,
      ${parseTimestampSql("posted_datetime")} AS posted_ts,
      ${parseTimestampSql("effective_datetime")} AS effective_ts,
      ${parseTimestampSql("end_datetime")} AS end_ts,
      (
        subject ~* '${CLOSED_NOTICE_SUBJECT_REGEX}'
        OR COALESCE(notice_status, '') ~* '(terminate|supersede)'
      ) AS is_deactivated_like
    FROM gas_ebbs.notices
  )
`;

const activePredicate = `
  effective_ts IS NOT NULL
  AND effective_ts <= now()
  AND (
    (end_ts IS NOT NULL AND end_ts >= now())
    OR (end_ts IS NULL AND posted_ts >= now() - interval '${OPEN_ENDED_RECENCY_DAYS} days')
  )
  AND NOT is_deactivated_like
`;

const upcomingPredicate = `
  effective_ts IS NOT NULL
  AND effective_ts > now()
  AND NOT is_deactivated_like
`;

type SummaryRow = {
  total_notices: number;
  source_families: number;
  pipelines: number;
  active_notices: number;
  upcoming_notices: number;
  affected_pipelines: number;
  high_severity_active: number;
  latest_scrape_at: string | null;
};

type TimePointRow = { date: string; notices: number };

type CategoryRow = { notice_category: string; notices: number };

type PipelineRow = { pipeline_name: string; notices: number };

type SourceFamilyRow = { source_family: string; notices: number };

type NoticeRow = {
  source_family: string;
  pipeline_name: string;
  notice_identifier: string;
  notice_type: string;
  notice_subtype: string;
  subject: string;
  notice_status: string;
  posted_datetime: string;
  effective_datetime: string;
  end_datetime: string;
  response_datetime: string;
  detail_url: string;
  notice_category: string;
  severity: number;
  scraped_at: string;
  posted_ts: string | null;
  effective_ts: string | null;
  end_ts: string | null;
  timing_state: GasEbbTimingState;
  is_active_heuristic: boolean;
  is_upcoming: boolean;
};

type TimelineRow = {
  source_family: string;
  pipeline_name: string;
  notice_identifier: string;
  subject: string;
  notice_category: string;
  severity: number;
  effective_ts: string | null;
  end_ts: string | null;
  timing_state: GasEbbTimingState;
};

const timingStateSql = `
  CASE
    WHEN ${activePredicate} THEN 'active'
    WHEN ${upcomingPredicate} THEN 'upcoming'
    WHEN effective_ts IS NULL THEN 'unknown'
    WHEN end_ts IS NULL THEN 'open_ended'
    ELSE 'ended'
  END AS timing_state
`;

export async function GET() {
  try {
    const [
      summaryResult,
      overTimeResult,
      categoryResult,
      pipelineResult,
      sourceFamilyResult,
      noticesResult,
      timelineResult,
    ] = await Promise.all([
      query<SummaryRow>(`
        ${normalizedNoticesCte}
        , snapshot_meta AS (
          SELECT MAX(scraped_at::timestamptz) AS latest_snapshot_scrape
          FROM gas_ebbs.notice_snapshots
        )
        SELECT
          COUNT(*)::int AS total_notices,
          COUNT(DISTINCT source_family)::int AS source_families,
          COUNT(DISTINCT pipeline_name)::int AS pipelines,
          COUNT(*) FILTER (WHERE ${activePredicate})::int AS active_notices,
          COUNT(*) FILTER (WHERE ${upcomingPredicate})::int AS upcoming_notices,
          COUNT(DISTINCT pipeline_name) FILTER (WHERE ${activePredicate})::int AS affected_pipelines,
          COUNT(*) FILTER (WHERE ${activePredicate} AND severity >= 4)::int AS high_severity_active,
          GREATEST(MAX(scraped_at_ts), (SELECT latest_snapshot_scrape FROM snapshot_meta))::text AS latest_scrape_at
        FROM normalized_notices
      `),
      query<TimePointRow>(`
        WITH snapshot_points AS (
          SELECT scraped_at::timestamptz AS scraped_at_ts
          FROM gas_ebbs.notice_snapshots
        )
        SELECT
          scraped_at_ts::date::text AS date,
          COUNT(*)::int AS notices
        FROM snapshot_points
        WHERE scraped_at_ts >= now() - interval '120 days'
        GROUP BY scraped_at_ts::date
        ORDER BY scraped_at_ts::date
      `),
      query<CategoryRow>(`
        ${normalizedNoticesCte}
        SELECT
          COALESCE(NULLIF(notice_category, ''), 'other') AS notice_category,
          COUNT(*)::int AS notices
        FROM normalized_notices
        WHERE ${activePredicate}
        GROUP BY notice_category
        ORDER BY notices DESC, notice_category
      `),
      query<PipelineRow>(`
        ${normalizedNoticesCte}
        SELECT
          pipeline_name,
          COUNT(*)::int AS notices
        FROM normalized_notices
        WHERE ${activePredicate}
        GROUP BY pipeline_name
        ORDER BY notices DESC, pipeline_name
        LIMIT 12
      `),
      query<SourceFamilyRow>(`
        ${normalizedNoticesCte}
        SELECT
          source_family,
          COUNT(*)::int AS notices
        FROM normalized_notices
        WHERE ${activePredicate}
        GROUP BY source_family
        ORDER BY notices DESC, source_family
      `),
      query<NoticeRow>(`
        ${normalizedNoticesCte}
        SELECT
          source_family,
          pipeline_name,
          notice_identifier,
          notice_type,
          notice_subtype,
          subject,
          notice_status,
          posted_datetime,
          effective_datetime,
          end_datetime,
          response_datetime,
          detail_url,
          notice_category,
          severity,
          scraped_at,
          posted_ts::text,
          effective_ts::text,
          end_ts::text,
          ${timingStateSql},
          (${activePredicate}) AS is_active_heuristic,
          (${upcomingPredicate}) AS is_upcoming
        FROM normalized_notices
        ORDER BY
          CASE
            WHEN ${activePredicate} THEN 0
            WHEN ${upcomingPredicate} THEN 1
            ELSE 2
          END,
          COALESCE(effective_ts, posted_ts) DESC NULLS LAST,
          severity DESC,
          pipeline_name
        LIMIT 250
      `),
      query<TimelineRow>(`
        ${normalizedNoticesCte}
        SELECT
          source_family,
          pipeline_name,
          notice_identifier,
          subject,
          notice_category,
          severity,
          effective_ts::text,
          end_ts::text,
          ${timingStateSql}
        FROM normalized_notices
        WHERE effective_ts IS NOT NULL
          AND (
            ${activePredicate}
            OR ${upcomingPredicate}
            OR (end_ts IS NOT NULL AND end_ts >= now() - interval '${TIMELINE_RECENT_ENDED_DAYS} days')
          )
        ORDER BY
          CASE
            WHEN ${activePredicate} THEN 0
            WHEN ${upcomingPredicate} THEN 1
            ELSE 2
          END,
          COALESCE(effective_ts, posted_ts) ASC NULLS LAST,
          severity DESC
        LIMIT 40
      `),
    ]);

    const summary = summaryResult.rows[0];

    const response: GasEbbDashboardResponse = {
      asOf: new Date().toISOString(),
      hero: {
        sourceFamilies: summary?.source_families ?? 0,
        pipelines: summary?.pipelines ?? 0,
        totalNotices: summary?.total_notices ?? 0,
      },
      kpis: {
        activeNotices: summary?.active_notices ?? 0,
        upcomingNotices: summary?.upcoming_notices ?? 0,
        affectedPipelines: summary?.affected_pipelines ?? 0,
        highSeverityActive: summary?.high_severity_active ?? 0,
        totalNotices: summary?.total_notices ?? 0,
        latestScrapeAt: summary?.latest_scrape_at ?? null,
      },
      charts: {
        noticesOverTime: overTimeResult.rows.map((row) => ({
          date: row.date,
          notices: row.notices,
        })),
        byCategory: categoryResult.rows.map((row) => ({
          noticeCategory: row.notice_category,
          notices: row.notices,
        })),
        byPipeline: pipelineResult.rows.map((row) => ({
          pipelineName: row.pipeline_name,
          notices: row.notices,
        })),
        bySourceFamily: sourceFamilyResult.rows.map((row) => ({
          sourceFamily: row.source_family,
          notices: row.notices,
        })),
      },
      notices: noticesResult.rows.map((row) => ({
        sourceFamily: row.source_family,
        pipelineName: row.pipeline_name,
        noticeIdentifier: row.notice_identifier,
        noticeType: row.notice_type,
        noticeSubtype: row.notice_subtype,
        subject: row.subject,
        noticeStatus: row.notice_status,
        postedDatetime: row.posted_datetime,
        effectiveDatetime: row.effective_datetime,
        endDatetime: row.end_datetime,
        responseDatetime: row.response_datetime,
        detailUrl: row.detail_url,
        noticeCategory: row.notice_category,
        severity: row.severity,
        scrapedAt: row.scraped_at,
        postedTs: row.posted_ts,
        effectiveTs: row.effective_ts,
        endTs: row.end_ts,
        timingState: row.timing_state,
        isActiveHeuristic: row.is_active_heuristic,
        isUpcoming: row.is_upcoming,
      })),
      timeline: timelineResult.rows.map((row) => ({
        sourceFamily: row.source_family,
        pipelineName: row.pipeline_name,
        noticeIdentifier: row.notice_identifier,
        subject: row.subject,
        noticeCategory: row.notice_category,
        severity: row.severity,
        effectiveTs: row.effective_ts,
        endTs: row.end_ts,
        timingState: row.timing_state,
      })),
    };

    return NextResponse.json<GasEbbDashboardResponse>(response);
  } catch (err) {
    console.error("Gas EBB dashboard API error:", err);
    return NextResponse.json(
      { error: "Failed to load Gas EBB dashboard data" },
      { status: 500 },
    );
  }
}
