/**
 * TypeScript interfaces for the Data Explorer feature.
 */

export interface SchemaInfo {
  name: string;
  tables: TableInfo[];
}

export interface TableInfo {
  name: string;
  type: "BASE TABLE" | "VIEW";
}

export interface ColumnInfo {
  column_name: string;
  data_type: string;
  is_nullable: string;
  ordinal_position: number;
}

export interface CatalogResponse {
  schemas: SchemaInfo[];
}

export interface ColumnsResponse {
  columns: ColumnInfo[];
  schema: string;
  table: string;
}

export interface QueryResult {
  columns: string[];
  rows: Record<string, unknown>[];
  rowCount: number;
  truncated: boolean;
  executionTimeMs: number;
}

export interface PreviewResponse extends QueryResult {
  schema: string;
  table: string;
}

export interface QueryRequest {
  sql: string;
  limit?: number;
}

export type ChartType = "line" | "bar" | "area" | "scatter" | "forecast";

export type GasEbbTimingState =
  | "active"
  | "upcoming"
  | "ended"
  | "open_ended"
  | "unknown";

export interface GasEbbKpiSummary {
  activeNotices: number;
  upcomingNotices: number;
  affectedPipelines: number;
  highSeverityActive: number;
  totalNotices: number;
  latestScrapeAt: string | null;
}

export interface GasEbbHeroSummary {
  sourceFamilies: number;
  pipelines: number;
  totalNotices: number;
}

export interface GasEbbNoticeRow {
  sourceFamily: string;
  pipelineName: string;
  noticeIdentifier: string;
  noticeType: string;
  noticeSubtype: string;
  subject: string;
  noticeStatus: string;
  postedDatetime: string;
  effectiveDatetime: string;
  endDatetime: string;
  responseDatetime: string;
  detailUrl: string;
  noticeCategory: string;
  severity: number;
  scrapedAt: string;
  postedTs: string | null;
  effectiveTs: string | null;
  endTs: string | null;
  timingState: GasEbbTimingState;
  isActiveHeuristic: boolean;
  isUpcoming: boolean;
}

export interface GasEbbOutageKpis {
  activeOutages: number;
  upcomingOutages: number;
  capacityAtRiskBcfd: number;
}

export interface GasEbbDashboardResponse {
  asOf: string;
  hero: GasEbbHeroSummary;
  kpis: GasEbbKpiSummary;
  outageKpis: GasEbbOutageKpis;
  notices: GasEbbNoticeRow[];
}
