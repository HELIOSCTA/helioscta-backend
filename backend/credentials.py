import os
from dotenv import load_dotenv
from pathlib import Path

import logging

logging.basicConfig(level=logging.INFO)
logging.getLogger().handlers[0].setLevel(logging.INFO)

env_file = Path(__file__).parent / ".env"
if not env_file.exists():
    raise FileNotFoundError(f"Environment file not found: {env_file}")

logging.info(f"Loading {env_file}")
load_dotenv(dotenv_path=env_file, override=True)

# ────── Azure PostgreSQL ──────
AZURE_POSTGRESQL_DB_HOST = os.getenv("AZURE_POSTGRESQL_DB_HOST")
AZURE_POSTGRESQL_DB_USER = os.getenv("AZURE_POSTGRESQL_DB_USER")
AZURE_POSTGRESQL_DB_PASSWORD = os.getenv("AZURE_POSTGRESQL_DB_PASSWORD")
AZURE_POSTGRESQL_DB_PORT = os.getenv("AZURE_POSTGRESQL_DB_PORT")
AZURE_POSTGRESQL_DB_NAME = os.getenv("AZURE_POSTGRESQL_DB_NAME")

# Read-only role used by backend/dbt/ for compile-only operation. Same
# host/port/dbname as above; distinct user with SELECT-only grants.
AZURE_POSTGRESQL_DB_READONLY_USER = os.getenv("AZURE_POSTGRESQL_DB_READONLY_USER")
AZURE_POSTGRESQL_DB_READONLY_PASSWORD = os.getenv("AZURE_POSTGRESQL_DB_READONLY_PASSWORD")

# ────── AWS PostgreSQL (read-only) ──────
AWS_POSTGRESQL_DB_HOST = os.getenv("AWS_POSTGRESQL_DB_HOST")
AWS_POSTGRESQL_DB_USER = os.getenv("AWS_POSTGRESQL_DB_USER")
AWS_POSTGRESQL_DB_PASSWORD = os.getenv("AWS_POSTGRESQL_DB_PASSWORD")
AWS_POSTGRESQL_DB_PORT = os.getenv("AWS_POSTGRESQL_DB_PORT")
AWS_POSTGRESQL_DB_NAME = os.getenv("AWS_POSTGRESQL_DB_NAME")
AWS_POSTGRESQL_DB_SSLMODE = os.getenv("AWS_POSTGRESQL_DB_SSLMODE", "require")

# ────── Azure SQL Server ──────
AZURE_SQL_SERVER = os.getenv("AZURE_SQL_SERVER")
AZURE_SQL_USER = os.getenv("AZURE_SQL_USER")
AZURE_SQL_PASSWORD = os.getenv("AZURE_SQL_PASSWORD")

# ────── Azure Outlook (Graph API) ──────
AZURE_OUTLOOK_CLIENT_ID = os.getenv("AZURE_OUTLOOK_CLIENT_ID")
AZURE_OUTLOOK_TENANT_ID = os.getenv("AZURE_OUTLOOK_TENANT_ID")
AZURE_OUTLOOK_CLIENT_SECRET = os.getenv("AZURE_OUTLOOK_CLIENT_SECRET")

# ────── Azure Blob Storage ──────
AZURE_STORAGE_CONNECTION_STRING = os.getenv("AZURE_STORAGE_CONNECTION_STRING")
AZURE_STORAGE_ACCOUNT_NAME = os.getenv("AZURE_STORAGE_ACCOUNT_NAME")
AZURE_CONTAINER_NAME = os.getenv("AZURE_CONTAINER_NAME")

# ────── Slack ──────
SLACK_DEFAULT_GROUP_ID = os.getenv("SLACK_DEFAULT_GROUP_ID")
SLACK_BOT_TOKEN = os.getenv("SLACK_BOT_TOKEN")
SLACK_DEFAULT_CHANNEL_NAME = os.getenv("SLACK_DEFAULT_CHANNEL_NAME")
SLACK_DEFAULT_WEBHOOK_URL = os.getenv("SLACK_DEFAULT_WEBHOOK_URL")

# ────── POWER──────
# GRIDSTATUS CREDENTIALS
GRIDSTATUS_API_KEY = os.getenv("GRIDSTATUS_API_KEY")

# PJM CREDENTIALS
PJM_API_KEY = os.getenv("PJM_API_KEY")

# ────── WSI ──────
WSI_TRADER_USERNAME = os.getenv("WSI_TRADER_USERNAME")
WSI_TRADER_NAME = os.getenv("WSI_TRADER_NAME")
WSI_TRADER_PASSWORD = os.getenv("WSI_TRADER_PASSWORD")

# ────── METEOLOGICA ──────
# Lower 48 (US48 aggregate) account
XTRADERS_API_USERNAME_L48 = os.getenv("XTRADERS_API_USERNAME_L48")
XTRADERS_API_PASSWORD_L48 = os.getenv("XTRADERS_API_PASSWORD_L48")

# ISO-level account (PJM, ERCOT, MISO, etc.)
XTRADERS_API_USERNAME_ISO = os.getenv("XTRADERS_API_USERNAME_ISO")
XTRADERS_API_PASSWORD_ISO = os.getenv("XTRADERS_API_PASSWORD_ISO")

# ────── ENERGY ASPECTS ──────
# ENERGY ASPECTS CREDENTIALS
ENERGY_ASPECTS_API_KEY = os.getenv("ENERGY_ASPECTS_API_KEY")

# ────── EIA ──────
# Free API key from https://www.eia.gov/opendata/register.php
EIA_API_KEY = os.getenv("EIA_API_KEY")

# ────── SFTP feeds (NAV / Marex / Clear Street / MUFG) ──────
# Clear Street uses an RSA private key (CLEAR_STREET_SSH_KEY_CONTENT),
# not a password. NAV/Marex/MUFG use password auth.
CLEAR_STREET_SFTP_HOST = os.getenv("CLEAR_STREET_SFTP_HOST")
CLEAR_STREET_SFTP_USER = os.getenv("CLEAR_STREET_SFTP_USER")
CLEAR_STREET_SFTP_PORT = int(os.getenv("CLEAR_STREET_SFTP_PORT")) if os.getenv("CLEAR_STREET_SFTP_PORT") else None
CLEAR_STREET_SFTP_REMOTE_DIR = r'/'
CLEAR_STREET_SSH_KEY_CONTENT = os.getenv("CLEAR_STREET_SSH_KEY_CONTENT")

MUFG_SFTP_HOST = os.getenv("MUFG_SFTP_HOST")
MUFG_SFTP_USER = os.getenv("MUFG_SFTP_USER")
MUFG_SFTP_PASSWORD = os.getenv("MUFG_SFTP_PASSWORD")
MUFG_SFTP_PORT = int(os.getenv("MUFG_SFTP_PORT")) if os.getenv("MUFG_SFTP_PORT") else None
MUFG_SFTP_REMOTE_DIR = r'/'

MAREX_SFTP_HOST = os.getenv("MAREX_SFTP_HOST")
MAREX_SFTP_USER = os.getenv("MAREX_SFTP_USER")
MAREX_SFTP_PASSWORD = os.getenv("MAREX_SFTP_PASSWORD")
MAREX_SFTP_PORT = int(os.getenv("MAREX_SFTP_PORT")) if os.getenv("MAREX_SFTP_PORT") else None
MAREX_SFTP_REMOTE_DIR = r'/'

NAV_SFTP_HOST = os.getenv("NAV_SFTP_HOST")
NAV_SFTP_USER = os.getenv("NAV_SFTP_USER")
NAV_SFTP_PASSWORD = os.getenv("NAV_SFTP_PASSWORD")
NAV_SFTP_PORT = int(os.getenv("NAV_SFTP_PORT")) if os.getenv("NAV_SFTP_PORT") else None
NAV_SFTP_REMOTE_DIR = r'/'
