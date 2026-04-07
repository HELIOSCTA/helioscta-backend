"""
Azure Blob Storage client for the backend.

Migrated from .refactor/helioscta_api_scrapes_gas_ebbs/utils/azure_blob_storage_utils.py.
Uses backend.secrets for credential loading instead of dotenv.
"""

import logging
from datetime import datetime, timezone
from typing import Optional, Union

from azure.storage.blob import BlobServiceClient, ContentSettings, BlobClient
from azure.core.exceptions import AzureError

from backend import secrets


class AzureBlobStorageClient:
    """Client for Azure Blob Storage operations."""

    def __init__(
        self,
        connection_string: str = None,
        storage_account_name: str = None,
        container_name: str = None,
    ):
        self.connection_string = connection_string or secrets.AZURE_STORAGE_CONNECTION_STRING
        self.storage_account_name = storage_account_name or secrets.AZURE_STORAGE_ACCOUNT_NAME
        self.container_name = container_name or secrets.AZURE_CONTAINER_NAME

    def get_blob_service_client(self) -> BlobServiceClient:
        """Get a BlobServiceClient instance."""
        return BlobServiceClient.from_connection_string(self.connection_string)

    def get_blob_client(
        self,
        blob_name: str,
        container_name: Optional[str] = None,
    ) -> BlobClient:
        """Get a BlobClient for a specific blob."""
        container = container_name or self.container_name
        service_client = self.get_blob_service_client()
        return service_client.get_blob_client(container=container, blob=blob_name)

    def upload_blob(
        self,
        data: Union[str, bytes],
        blob_name: str,
        container_name: Optional[str] = None,
        content_type: Optional[str] = None,
        overwrite: bool = True,
        metadata: Optional[dict[str, str]] = None,
    ) -> str:
        """Upload data as a blob. Returns the blob URL."""
        container = container_name or self.container_name

        try:
            blob_client = self.get_blob_client(blob_name, container)

            content_settings = None
            if content_type:
                content_settings = ContentSettings(content_type=content_type)

            blob_client.upload_blob(
                data,
                overwrite=overwrite,
                content_settings=content_settings,
                metadata=metadata,
            )

            url = f"https://{self.storage_account_name}.blob.core.windows.net/{container}/{blob_name}"
            logging.info(f"Uploaded blob: {blob_name}")
            return url

        except AzureError as e:
            logging.error(f"Error uploading blob: {e}")
            raise

    def upload_html(
        self,
        html_content: str,
        blob_name: str,
        container_name: Optional[str] = None,
        overwrite: bool = True,
    ) -> str:
        """Upload HTML content as a blob."""
        if not blob_name.endswith(".html"):
            blob_name = f"{blob_name}.html"

        return self.upload_blob(
            data=html_content,
            blob_name=blob_name,
            container_name=container_name,
            content_type="text/html",
            overwrite=overwrite,
        )

    def upload_ebb_html(
        self,
        html: str,
        source_family: str,
        pipeline_name: str,
        page_type: str,
        notice_id: str = "",
    ) -> str:
        """Upload EBB HTML with auto-built path.

        Path: gas-ebbs/{source_family}/{pipeline_name}/{YYYY-MM-DD}/{id_or_ts}_{page_type}.html
        """
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        timestamp = datetime.now(timezone.utc).strftime("%H%M%S")
        filename = f"{notice_id}_{page_type}" if notice_id else f"{timestamp}_{page_type}"
        blob_name = f"gas-ebbs/{source_family}/{pipeline_name}/{today}/{filename}.html"

        return self.upload_html(html_content=html, blob_name=blob_name)

    def download_blob(
        self,
        blob_name: str,
        container_name: Optional[str] = None,
    ) -> bytes:
        """Download a blob's content."""
        try:
            blob_client = self.get_blob_client(blob_name, container_name)
            blob_data = blob_client.download_blob()
            return blob_data.readall()
        except AzureError as e:
            logging.error(f"Error downloading blob: {e}")
            raise

    def list_blobs(
        self,
        container_name: Optional[str] = None,
        name_starts_with: Optional[str] = None,
    ) -> list:
        """List blobs in a container."""
        container = container_name or self.container_name

        try:
            service_client = self.get_blob_service_client()
            container_client = service_client.get_container_client(container)
            blobs = container_client.list_blobs(name_starts_with=name_starts_with)
            return [blob.name for blob in blobs]
        except AzureError as e:
            logging.error(f"Error listing blobs: {e}")
            raise

    def blob_exists(
        self,
        blob_name: str,
        container_name: Optional[str] = None,
    ) -> bool:
        """Check if a blob exists."""
        try:
            blob_client = self.get_blob_client(blob_name, container_name)
            return blob_client.exists()
        except AzureError as e:
            logging.error(f"Error checking blob existence: {e}")
            return False
