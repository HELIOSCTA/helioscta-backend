"""
dbt assets for the positions_and_trades domain.

Uses dagster-dbt for first-class integration — each dbt model becomes
a Dagster asset with automatic lineage tracking.

Output view: trades_cleaned.clear_street_trades
"""

from pathlib import Path

from dagster import AssetKey
from dagster_dbt import DagsterDbtTranslator, DbtCliResource, DbtProject, dbt_assets


DBT_PROJECT_DIR = Path(__file__).resolve().parents[5] / "dbt" / "dbt_azure_postgresql"

dbt_project = DbtProject(project_dir=DBT_PROJECT_DIR)
dbt_project.prepare_if_dev()


class PositionsAndTradesDbtTranslator(DagsterDbtTranslator):
    """Map dbt sources to upstream Dagster assets."""

    def get_asset_key(self, dbt_resource_props):
        if dbt_resource_props.get("resource_type") == "source":
            if dbt_resource_props.get("source_name") == "clear_street_v2":
                return AssetKey("step_pull_from_clear_street")
        if dbt_resource_props.get("resource_type") == "model":
            if dbt_resource_props.get("name") == "clear_street_trades":
                return AssetKey("step_dbt_transform")
        return super().get_asset_key(dbt_resource_props)

    def get_group_name(self, dbt_resource_props):
        return "clear_street_to_mufg"


@dbt_assets(
    manifest=dbt_project.manifest_path,
    select="+clear_street_trades",
    dagster_dbt_translator=PositionsAndTradesDbtTranslator(),
)
def step_dbt_transform(context, dbt: DbtCliResource):
    yield from dbt.cli(["build"], context=context).stream()
