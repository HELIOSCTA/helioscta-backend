"""
Abstract base class for gas EBB scrapers.

Each source family (PipeRiv, Kinder Morgan, Williams, etc.) implements
a concrete adapter by subclassing EBBScraper and overriding _parse_listing().
Only override _pull() when the transport differs (session, Selenium, etc.).

Usage:
    scraper = create_scraper("piperiv", "algonquin")
    scraper.main()
"""

import yaml
from abc import ABC, abstractmethod
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

import pandas as pd
import requests

from backend import secrets  # noqa: F401 — ensures env vars are loaded
from backend.utils import (
    azure_postgresql_utils as azure_postgresql,
    logging_utils,
    pipeline_run_logger,
)

from backend.src.gas_ebbs import notice_classifier
from backend.src.gas_ebbs.ebb_utils import DEFAULT_HEADERS


# ── Storage constants ──────────────────────────────────────────────────────

SCHEMA = "gas_ebbs"
TABLE = "notices"
SNAPSHOT_TABLE = "notice_snapshots"

COLUMNS = [
    "source_family",
    "pipeline_name",
    "notice_identifier",
    "notice_type",
    "notice_subtype",
    "subject",
    "notice_status",
    "posted_datetime",
    "effective_datetime",
    "end_datetime",
    "response_datetime",
    "detail_url",
    "notice_category",
    "severity",
    "scraped_at",
]

DATA_TYPES = [
    "VARCHAR",   # source_family
    "VARCHAR",   # pipeline_name
    "VARCHAR",   # notice_identifier
    "VARCHAR",   # notice_type
    "VARCHAR",   # notice_subtype
    "VARCHAR",   # subject
    "VARCHAR",   # notice_status
    "VARCHAR",   # posted_datetime
    "VARCHAR",   # effective_datetime
    "VARCHAR",   # end_datetime
    "VARCHAR",   # response_datetime
    "VARCHAR",   # detail_url
    "VARCHAR",   # notice_category
    "INTEGER",   # severity
    "VARCHAR",   # scraped_at
]

PRIMARY_KEY = ["source_family", "pipeline_name", "notice_identifier"]

SNAPSHOT_COLUMNS = COLUMNS.copy()

SNAPSHOT_DATA_TYPES = DATA_TYPES.copy()

SNAPSHOT_PRIMARY_KEY = [
    "source_family",
    "pipeline_name",
    "notice_identifier",
    "scraped_at",
]


LOG_DIR = Path(__file__).parent / "logs"


# ── Base class ─────────────────────────────────────────────────────────────


class EBBScraper(ABC):
    """Abstract base class for all gas EBB source-family scrapers.

    Subclasses must implement ``_parse_listing()``.
    Override ``_pull()`` only when the HTTP transport differs from a simple GET
    (e.g. session bootstrap for Williams, Selenium for Tallgrass).
    """

    def __init__(
        self,
        pipeline_name: str,
        source_family: str,
        listing_url: str,
        detail_url_template: str = "",
        datetime_formats: Optional[list[str]] = None,
        config: Optional[dict] = None,
    ):
        self.pipeline_name = pipeline_name
        self.source_family = source_family
        self.listing_url = listing_url
        self.detail_url_template = detail_url_template
        self.datetime_formats = datetime_formats or []
        self.config = config or {}

    # ── Standard pipeline functions ────────────────────────────────────

    def _get_listing_sources(self) -> list[dict]:
        """Return list of source configs to scrape.

        Each dict must have ``url``. Additional keys are passed as
        keyword arguments to ``_parse_listing()``.

        Default: single URL from ``self.listing_url``.
        Override in adapters that need to scrape multiple pages per
        pipeline (e.g. Enbridge scrapes both CRI and NON pages).
        """
        return [{"url": self.listing_url}]

    def _pull(self, url: str = "") -> str:
        """Fetch listing page HTML via GET. Override for session/Selenium."""
        target = url or self.listing_url
        response = requests.get(
            target,
            headers=DEFAULT_HEADERS,
            timeout=30,
        )
        response.raise_for_status()
        return response.text

    @abstractmethod
    def _parse_listing(self, html: str, **kwargs) -> list[dict]:
        """Parse listing-page HTML into a list of raw notice dicts.

        Each dict should contain the fields available from the listing page:
            notice_type, notice_subtype, subject, notice_status,
            posted_datetime, effective_datetime, end_datetime,
            response_datetime, notice_identifier, detail_url

        Missing fields should be set to empty string, not omitted.

        Keyword arguments come from ``_get_listing_sources()`` context.
        """
        ...

    def _format(self, raw_notices: list[dict]) -> pd.DataFrame:
        """Normalize raw notice dicts into a DataFrame ready for upsert.

        Adds pipeline metadata, classification, and scraped_at timestamp.
        """
        if not raw_notices:
            return pd.DataFrame(columns=COLUMNS)

        df = pd.DataFrame(raw_notices)

        # Add pipeline metadata
        df["source_family"] = self.source_family
        df["pipeline_name"] = self.pipeline_name
        df["scraped_at"] = datetime.now(timezone.utc).isoformat()

        # Classify each notice by subject
        classifications = df["subject"].apply(notice_classifier.classify)
        df["notice_category"] = classifications.apply(lambda x: x[0])
        df["severity"] = classifications.apply(lambda x: x[1])

        # Ensure all expected columns exist
        for col in COLUMNS:
            if col not in df.columns:
                df[col] = ""

        # Reorder to canonical column order
        df = df[COLUMNS]

        # Fill NaN with empty string for VARCHAR columns, 0 for severity
        for col in df.columns:
            if col == "severity":
                df[col] = df[col].fillna(0).astype(int)
            else:
                df[col] = df[col].fillna("").astype(str)

        return df

    def _upsert(self, df: pd.DataFrame) -> None:
        """Upsert notices to gas_ebbs.notices and gas_ebbs.notice_snapshots."""
        if df.empty:
            return

        # Upsert to canonical notices table
        azure_postgresql.upsert_to_azure_postgresql(
            schema=SCHEMA,
            table_name=TABLE,
            df=df,
            columns=COLUMNS,
            data_types=DATA_TYPES,
            primary_key=PRIMARY_KEY,
        )

        # Append to snapshot table for revision history
        azure_postgresql.upsert_to_azure_postgresql(
            schema=SCHEMA,
            table_name=SNAPSHOT_TABLE,
            df=df,
            columns=SNAPSHOT_COLUMNS,
            data_types=SNAPSHOT_DATA_TYPES,
            primary_key=SNAPSHOT_PRIMARY_KEY,
        )

    def main(self) -> list[dict]:
        """Full scrape pipeline: pull -> parse -> format -> classify -> upsert.

        Returns the list of raw notice dicts (before formatting).
        """
        api_scrape_name = f"gas_ebb_{self.pipeline_name}"
        logger = logging_utils.init_logging(
            name=api_scrape_name,
            log_dir=LOG_DIR,
            log_to_file=True,
            delete_if_no_errors=True,
        )

        run = pipeline_run_logger.PipelineRunLogger(
            pipeline_name=api_scrape_name,
            source="gas_ebbs",
            target_table=f"{SCHEMA}.{TABLE}",
            operation_type="upsert",
            log_file_path=logger.log_file_path,
        )
        run.start()

        try:
            logger.header(api_scrape_name)

            listing_sources = self._get_listing_sources()
            raw_notices = []

            for source in listing_sources:
                url = source["url"]
                context = {k: v for k, v in source.items() if k != "url"}
                label = context.get("label", url)

                logger.section(f"Pulling: {label}")
                logger.info(f"URL: {url}")
                html = self._pull(url)
                logger.info(f"Fetched {len(html):,} bytes")

                notices = self._parse_listing(html, **context)
                logger.info(f"Parsed {len(notices)} notices")
                raw_notices.extend(notices)

            if not raw_notices:
                logger.warning("No notices found. Page structure may have changed.")
                run.success(rows_processed=0)
                return []

            logger.section("Formatting and Classifying")
            df = self._format(raw_notices)
            logger.info(f"Formatted {len(df)} notices")

            # Log classification breakdown
            if not df.empty:
                counts = df["notice_category"].value_counts().to_dict()
                for cat, count in counts.items():
                    logger.info(f"  {cat}: {count}")

            logger.section("Upserting to Database")
            self._upsert(df)
            logger.success(
                f"Upserted {len(df)} notices to {SCHEMA}.{TABLE}"
            )

            run.success(rows_processed=len(df))
            return raw_notices

        except Exception as e:
            logger.exception(f"Pipeline failed: {e}")
            run.failure(error=e)
            raise

        finally:
            logging_utils.close_logging()


# ── Adapter registry + factory ─────────────────────────────────────────────

ADAPTER_REGISTRY: dict[str, type[EBBScraper]] = {}


def register_adapter(source_family: str):
    """Decorator to register an adapter class for a source family."""

    def decorator(cls: type[EBBScraper]):
        ADAPTER_REGISTRY[source_family] = cls
        return cls

    return decorator


def _ensure_adapters_loaded():
    """Import adapter modules so they register themselves."""
    if ADAPTER_REGISTRY:
        return
    # Import all adapter modules — each uses @register_adapter
    from backend.src.gas_ebbs.adapters import piperiv_adapter  # noqa: F401
    from backend.src.gas_ebbs.adapters import enbridge_adapter  # noqa: F401
    from backend.src.gas_ebbs.adapters import kindermorgan_adapter  # noqa: F401
    from backend.src.gas_ebbs.adapters import williams_adapter  # noqa: F401
    from backend.src.gas_ebbs.adapters import energytransfer_adapter  # noqa: F401
    from backend.src.gas_ebbs.adapters import tce_adapter  # noqa: F401
    from backend.src.gas_ebbs.adapters import tcplus_adapter  # noqa: F401
    from backend.src.gas_ebbs.adapters import quorum_adapter  # noqa: F401
    from backend.src.gas_ebbs.adapters import bhegts_adapter  # noqa: F401
    from backend.src.gas_ebbs.adapters import northern_natural_adapter  # noqa: F401
    from backend.src.gas_ebbs.adapters import dtmidstream_adapter  # noqa: F401
    from backend.src.gas_ebbs.adapters import gasnom_adapter  # noqa: F401
    from backend.src.gas_ebbs.adapters import tallgrass_adapter  # noqa: F401
    from backend.src.gas_ebbs.adapters import cheniere_adapter  # noqa: F401
    from backend.src.gas_ebbs.adapters import standalone_adapter  # noqa: F401


CONFIG_DIR = Path(__file__).parent / "config"


def load_family_config(config_path: Path) -> dict:
    """Load and return a source-family YAML config."""
    with open(config_path, encoding="utf-8") as f:
        return yaml.safe_load(f)


def _resolve_pipeline_config(family_config: dict, pipeline_name: str) -> dict:
    """Merge family defaults with pipeline-specific overrides."""
    defaults = family_config.get("defaults", {})
    pipeline_overrides = family_config["pipelines"][pipeline_name]

    config = {**defaults, **pipeline_overrides}
    config["source_family"] = family_config["source_family"]
    config["pipeline_name"] = pipeline_name

    # Render URL templates
    if "listing_url_template" in config and "listing_url" not in config:
        config["listing_url"] = config["listing_url_template"].format(**config)
    if "detail_url_template" in config:
        # Keep the template — it gets rendered per-notice at parse time
        pass

    return config


def create_scraper(source_family: str, pipeline_name: str) -> EBBScraper:
    """Load YAML config and return the correct adapter instance.

    Args:
        source_family: e.g. "piperiv", "kindermorgan", "williams"
        pipeline_name: e.g. "algonquin", "tgp", "transco"
    """
    _ensure_adapters_loaded()

    # Find the YAML config for this family
    config_path = CONFIG_DIR / f"{source_family}.yaml"
    if not config_path.exists():
        raise FileNotFoundError(f"No config found: {config_path}")

    family_config = load_family_config(config_path)
    if pipeline_name not in family_config.get("pipelines", {}):
        available = list(family_config.get("pipelines", {}).keys())
        raise ValueError(
            f"Pipeline '{pipeline_name}' not found in {source_family}.yaml. "
            f"Available: {available}"
        )

    config = _resolve_pipeline_config(family_config, pipeline_name)

    adapter_cls = ADAPTER_REGISTRY.get(source_family)
    if adapter_cls is None:
        raise ValueError(
            f"No adapter registered for '{source_family}'. "
            f"Available: {list(ADAPTER_REGISTRY.keys())}"
        )

    return adapter_cls(
        pipeline_name=pipeline_name,
        source_family=source_family,
        listing_url=config["listing_url"],
        detail_url_template=config.get("detail_url_template", ""),
        datetime_formats=config.get("datetime_formats", []),
        config=config,
    )


def discover_all_pipelines() -> list[tuple[str, str, Path]]:
    """Discover all configured pipelines across all YAML configs.

    Skips pipelines with ``disabled: true`` in their config.

    Returns a sorted list of (pipeline_name, source_family, config_path) tuples.
    """
    pipelines = []
    for yaml_file in sorted(CONFIG_DIR.glob("*.yaml")):
        family_config = load_family_config(yaml_file)
        source_family = family_config["source_family"]
        for name, pconfig in sorted(family_config.get("pipelines", {}).items()):
            if isinstance(pconfig, dict) and pconfig.get("disabled"):
                continue
            pipelines.append((name, source_family, yaml_file))
    return pipelines
