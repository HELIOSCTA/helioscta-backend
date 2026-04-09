"""
Validate Grafana dashboard JSON files before deployment.

Checks:
  1. JSON is well-formed
  2. Required top-level fields exist (uid, title, panels)
  3. No duplicate panel IDs
  4. Text panels have non-empty markdown content
  5. SQL targets reference tables in known schemas
  6. Provisioning config covers every dashboard folder
  7. No placeholder URLs left in text panels (GRAFANA_GATEWAY_FQDN, DOCS_SWA_FQDN)

Usage:
    python backend/grafana/validate_dashboards.py          # static checks only
    python backend/grafana/validate_dashboards.py --db      # also verify tables exist in PostgreSQL
"""

import argparse
import json
import re
import sys
from pathlib import Path

GRAFANA_DIR = Path(__file__).parent
DASHBOARDS_DIR = GRAFANA_DIR / "dashboards"
PROVISIONING_FILE = GRAFANA_DIR / "provisioning" / "dashboards" / "dashboards.yml"

KNOWN_SCHEMAS = {
    "positions_cleaned",
    "trades_cleaned",
    "logging",
    "eia",
    "clear_street",
    "marex",
    "nav",
}

PLACEHOLDER_PATTERNS = [
    "GRAFANA_GATEWAY_FQDN",
    "DOCS_SWA_FQDN",
    "PLACEHOLDER",
    "TODO",
    "FIXME",
]

REQUIRED_FIELDS = ["uid", "title", "panels"]


def load_dashboard(path: Path) -> dict:
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def extract_sql_tables(sql: str) -> list[tuple[str, str]]:
    """Extract schema.table references from raw SQL (ignoring numeric literals)."""
    return [(schema, table) for schema, table in re.findall(r"([a-zA-Z_]\w*)\.([a-zA-Z_]\w*)", sql)]


def check_structure(dashboard: dict, path: Path, errors: list[str]):
    for field in REQUIRED_FIELDS:
        if field not in dashboard:
            errors.append(f"{path.name}: missing required field '{field}'")

    panel_ids = []
    for panel in dashboard.get("panels", []):
        pid = panel.get("id")
        if pid in panel_ids:
            errors.append(f"{path.name}: duplicate panel id {pid}")
        panel_ids.append(pid)


def check_text_panels(dashboard: dict, path: Path, errors: list[str], warnings: list[str]):
    for panel in dashboard.get("panels", []):
        if panel.get("type") != "text":
            continue

        content = panel.get("options", {}).get("content", "")
        pid = panel.get("id")
        title = panel.get("title", f"panel {pid}")

        if not content.strip():
            errors.append(f"{path.name}: text panel '{title}' has empty content")
            continue

        # Check for placeholder URLs
        for placeholder in PLACEHOLDER_PATTERNS:
            if placeholder in content:
                errors.append(f"{path.name}: text panel '{title}' contains placeholder '{placeholder}'")

        # Check markdown table alignment (pipes should be balanced)
        for i, line in enumerate(content.split("\n"), 1):
            stripped = line.strip()
            if stripped.startswith("|") and stripped.endswith("|"):
                pipe_count = stripped.count("|")
                if pipe_count < 3:
                    warnings.append(
                        f"{path.name}: text panel '{title}' line {i} — table row has only {pipe_count} pipes"
                    )


def check_sql_schemas(dashboard: dict, path: Path, warnings: list[str]):
    for panel in dashboard.get("panels", []):
        for target in panel.get("targets", []):
            sql = target.get("rawSql", "")
            for schema, table in extract_sql_tables(sql):
                if schema not in KNOWN_SCHEMAS and schema not in (
                    "information_schema",
                    "pg_catalog",
                ):
                    warnings.append(
                        f"{path.name}: panel '{panel.get('title', '?')}' "
                        f"references unknown schema '{schema}' (table: {table})"
                    )


def check_provisioning(dashboard_folders: list[str], errors: list[str]):
    if not PROVISIONING_FILE.exists():
        errors.append(f"Provisioning file not found: {PROVISIONING_FILE}")
        return

    provisioning_text = PROVISIONING_FILE.read_text(encoding="utf-8")
    for folder in dashboard_folders:
        if folder not in provisioning_text:
            errors.append(f"Dashboard folder '{folder}' not found in provisioning config ({PROVISIONING_FILE.name})")


def check_db_tables(dashboard: dict, path: Path, conn, errors: list[str]):
    """Query PostgreSQL to verify referenced tables/views exist."""
    cursor = conn.cursor()
    checked = set()

    for panel in dashboard.get("panels", []):
        for target in panel.get("targets", []):
            sql = target.get("rawSql", "")
            for schema, table in extract_sql_tables(sql):
                key = f"{schema}.{table}"
                if key in checked or schema not in KNOWN_SCHEMAS:
                    continue
                checked.add(key)

                cursor.execute(
                    """
                    SELECT EXISTS (
                        SELECT 1 FROM information_schema.tables
                        WHERE table_schema = %s AND table_name = %s
                    ) OR EXISTS (
                        SELECT 1 FROM information_schema.views
                        WHERE table_schema = %s AND table_name = %s
                    )
                    """,
                    (schema, table, schema, table),
                )
                exists = cursor.fetchone()[0]
                if not exists:
                    errors.append(
                        f"{path.name}: panel '{panel.get('title', '?')}' "
                        f"references {key} which does not exist in the database"
                    )

    cursor.close()


def main():
    parser = argparse.ArgumentParser(description="Validate Grafana dashboards")
    parser.add_argument(
        "--db",
        action="store_true",
        help="Also verify SQL table references against PostgreSQL",
    )
    args = parser.parse_args()

    errors: list[str] = []
    warnings: list[str] = []

    # Find all dashboard JSON files
    json_files = sorted(DASHBOARDS_DIR.rglob("*.json"))
    if not json_files:
        errors.append(f"No dashboard JSON files found in {DASHBOARDS_DIR}")

    # Track folder names for provisioning check
    dashboard_folders = set()

    conn = None
    if args.db:
        try:
            import psycopg2

            from backend.env_config import (
                AZURE_POSTGRESQL_DB_HOST,
                AZURE_POSTGRESQL_DB_NAME,
                AZURE_POSTGRESQL_DB_PASSWORD,
                AZURE_POSTGRESQL_DB_PORT,
                AZURE_POSTGRESQL_DB_USER,
            )

            conn = psycopg2.connect(
                host=AZURE_POSTGRESQL_DB_HOST,
                port=AZURE_POSTGRESQL_DB_PORT,
                dbname=AZURE_POSTGRESQL_DB_NAME,
                user=AZURE_POSTGRESQL_DB_USER,
                password=AZURE_POSTGRESQL_DB_PASSWORD,
            )
        except Exception as e:
            errors.append(f"--db: could not connect to PostgreSQL: {e}")

    print(f"Validating {len(json_files)} dashboard(s)...\n")

    for json_file in json_files:
        folder_name = json_file.parent.name
        dashboard_folders.add(folder_name)

        # 1. JSON validity
        try:
            dashboard = load_dashboard(json_file)
        except json.JSONDecodeError as e:
            errors.append(f"{json_file.name}: invalid JSON — {e}")
            continue

        relative = json_file.relative_to(DASHBOARDS_DIR)
        print(f"  {relative}")

        # 2. Structure
        check_structure(dashboard, json_file, errors)

        # 3. Text panels
        check_text_panels(dashboard, json_file, errors, warnings)

        # 4. SQL schema references
        check_sql_schemas(dashboard, json_file, warnings)

        # 5. DB table verification
        if conn:
            check_db_tables(dashboard, json_file, conn, errors)

    # 6. Provisioning coverage
    check_provisioning(list(dashboard_folders), errors)

    if conn:
        conn.close()

    # Report
    print()
    if warnings:
        print(f"WARNINGS ({len(warnings)}):")
        for w in warnings:
            print(f"  WARN: {w}")
        print()

    if errors:
        print(f"ERRORS ({len(errors)}):")
        for e in errors:
            print(f"  FAIL: {e}")
        print()
        print("FAILED")
        sys.exit(1)
    else:
        print("PASSED -- all checks OK")
        sys.exit(0)


if __name__ == "__main__":
    main()

