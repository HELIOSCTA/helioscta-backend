"""
TC Energy (TCE Connects) source-family adapter.

Handles all pipelines hosted on www.tceconnects.com/infopost (11 pipelines).
TC Energy uses a JavaScript SPA with an underlying API for notice data.
The adapter attempts to call the JSON API first, falling back to HTML parsing.

Supported pipelines: ANR, ANRS, BISON, BLGS, TCO, CGUL, CROSS, HARDY,
                     MILL, NBPL, PNGTS

EBB: https://www.tceconnects.com/infopost/
"""

import json

from bs4 import BeautifulSoup

from backend.src.gas_ebbs.base_scraper import EBBScraper, register_adapter
from backend.src.gas_ebbs.ebb_utils import clean_text, extract_numeric_id, DEFAULT_HEADERS


BASE_URL = "https://www.tceconnects.com/infopost"

# Known API endpoint patterns for the TC Energy SPA
API_NOTICES_PATH = "/api/notices"

# Map notice type codes to labels
NOTICE_TYPE_LABELS = {
    "critical": "Critical",
    "non-critical": "Non-Critical",
}


@register_adapter("tce")
class TCEAdapter(EBBScraper):
    """Adapter for TC Energy (TCE Connects) EBB pages.

    TC Energy serves notices through a JavaScript SPA. The adapter tries
    to find and call the underlying JSON API first. If the API is not
    available or returns unexpected data, it falls back to HTML table
    parsing.

    Expected API JSON structure (per notice):
        - noticeType / NoticeType
        - postDateTime / PostDateTime
        - effectiveDateTime / EffectiveDateTime
        - endDateTime / EndDateTime
        - noticeId / NoticeId
        - subject / Subject
        - responseDateTime / ResponseDateTime

    HTML table fallback expects columns:
        0: Notice Type
        1: Posted Date/Time
        2: Effective Date/Time
        3: End Date/Time
        4: Notice ID (numeric)
        5: Subject (linked)
        6: Response Date/Time (if present)
    """

    def _get_listing_sources(self) -> list[dict]:
        """Return one source per configured notice type (critical, non-critical).

        Tries the JSON API endpoint first. Each source dict includes both
        the API URL and a fallback HTML URL.
        """
        pipe_code = self.config["pipe_code"]
        notice_types = self.config.get("notice_types", ["critical", "non-critical"])
        base = self.config.get("base_url", BASE_URL)

        return [
            {
                "url": f"{base}{API_NOTICES_PATH}?pipeline={pipe_code}&type={nt}",
                "fallback_url": f"{base}/MobileInfoPost.aspx?pipeline={pipe_code}&type={nt}",
                "notice_type_code": nt,
                "pipe_code": pipe_code,
                "label": (
                    f"{self.pipeline_name} "
                    f"({NOTICE_TYPE_LABELS.get(nt, nt)})"
                ),
            }
            for nt in notice_types
        ]

    def _pull(self, url: str = "") -> str:
        """Fetch from API endpoint, falling back to HTML page.

        Tries the JSON API first. If it returns a non-200 or non-JSON
        response, retries with Accept: text/html to get the SPA page.
        """
        import requests

        target = url or self.listing_url

        # Try JSON API first
        api_headers = {
            **DEFAULT_HEADERS,
            "Accept": "application/json, text/javascript, */*; q=0.01",
            "X-Requested-With": "XMLHttpRequest",
        }

        try:
            response = requests.get(target, headers=api_headers, timeout=30)
            if response.status_code == 200:
                # Check if response is actually JSON
                content_type = response.headers.get("Content-Type", "")
                if "json" in content_type or "javascript" in content_type:
                    return response.text
                # Try parsing as JSON anyway
                try:
                    json.loads(response.text)
                    return response.text
                except (json.JSONDecodeError, ValueError):
                    pass
        except requests.RequestException:
            pass

        # Fallback: fetch HTML page using the MobileInfoPost endpoint
        # The API URL path /api/notices doesn't have an HTML equivalent,
        # so swap to the known HTML endpoint which shares the same query params.
        fallback_url = target.replace("/api/notices", "/MobileInfoPost.aspx")
        response = requests.get(fallback_url, headers=DEFAULT_HEADERS, timeout=30)
        response.raise_for_status()
        return response.text

    def _parse_listing(self, html: str, **kwargs) -> list[dict]:
        notice_type_code = kwargs.get("notice_type_code", "critical")
        pipe_code = kwargs.get("pipe_code", self.config.get("pipe_code", ""))
        base = self.config.get("base_url", BASE_URL)

        # Try parsing as JSON first (from API response)
        notices = self._try_parse_json(html, notice_type_code, pipe_code, base)
        if notices is not None:
            return notices

        # Fallback: parse as HTML
        return self._parse_html(html, notice_type_code, pipe_code, base)

    def _try_parse_json(
        self, text: str, notice_type_code: str, pipe_code: str, base: str
    ) -> list[dict] | None:
        """Attempt to parse the response as JSON API data.

        Returns a list of notice dicts on success, or None if the text
        is not valid JSON or doesn't contain expected notice data.
        """
        try:
            data = json.loads(text)
        except (json.JSONDecodeError, ValueError):
            return None

        # Handle both list and dict-with-list structures
        if isinstance(data, dict):
            # Common patterns: {"data": [...]}, {"notices": [...]}, {"results": [...]}
            for key in ("data", "notices", "results", "items", "Notices", "Data"):
                if key in data and isinstance(data[key], list):
                    data = data[key]
                    break
            else:
                # If the dict itself isn't iterable as notices, bail
                if not isinstance(data, list):
                    return None

        if not isinstance(data, list) or len(data) == 0:
            return None

        # Verify first item looks like a notice (has identifiable fields)
        first = data[0]
        if not isinstance(first, dict):
            return None

        # Check for known field names (case-insensitive lookup)
        notice_field_names = {
            "noticeid", "notice_id", "NoticeId",
            "subject", "Subject",
            "noticeType", "NoticeType", "notice_type",
        }
        if not any(k in first for k in notice_field_names):
            return None

        notices = []
        for item in data:
            if not isinstance(item, dict):
                continue

            notice_id = str(
                item.get("noticeId")
                or item.get("NoticeId")
                or item.get("notice_id")
                or item.get("noticeIdentifier")
                or ""
            )
            if not notice_id:
                continue

            subject = str(
                item.get("subject")
                or item.get("Subject")
                or item.get("noticeSubject")
                or item.get("NoticeSubject")
                or ""
            )

            detail_url = str(
                item.get("detailUrl")
                or item.get("DetailUrl")
                or item.get("detail_url")
                or ""
            )
            if not detail_url:
                detail_url = (
                    f"{base}/MobileInfoPost.aspx"
                    f"?pipeline={pipe_code}&noticeId={notice_id}"
                )

            notice = {
                "notice_type": str(
                    item.get("noticeType")
                    or item.get("NoticeType")
                    or item.get("notice_type")
                    or NOTICE_TYPE_LABELS.get(notice_type_code, notice_type_code)
                ),
                "notice_subtype": "",
                "posted_datetime": str(
                    item.get("postDateTime")
                    or item.get("PostDateTime")
                    or item.get("posted_datetime")
                    or item.get("postDatetime")
                    or ""
                ),
                "effective_datetime": str(
                    item.get("effectiveDateTime")
                    or item.get("EffectiveDateTime")
                    or item.get("effective_datetime")
                    or item.get("effectiveDatetime")
                    or ""
                ),
                "end_datetime": str(
                    item.get("endDateTime")
                    or item.get("EndDateTime")
                    or item.get("end_datetime")
                    or item.get("endDatetime")
                    or ""
                ),
                "notice_identifier": notice_id,
                "notice_status": "",
                "subject": subject,
                "response_datetime": str(
                    item.get("responseDateTime")
                    or item.get("ResponseDateTime")
                    or item.get("response_datetime")
                    or item.get("responseDatetime")
                    or ""
                ),
                "detail_url": detail_url,
            }
            notices.append(notice)

        return notices if notices else None

    def _parse_html(
        self, html: str, notice_type_code: str, pipe_code: str, base: str
    ) -> list[dict]:
        """Fallback HTML table parser for TC Energy pages.

        Looks for the largest table on the page and extracts notice data
        from rows with at least 6 columns.
        """
        soup = BeautifulSoup(html, "html.parser")

        # Find the data table — use the largest table on the page
        tables = soup.find_all("table")
        if not tables:
            return []

        data_table = None
        max_rows = 0
        for table in tables:
            rows = table.find_all("tr")
            if len(rows) > max_rows:
                max_rows = len(rows)
                data_table = table

        if not data_table or max_rows < 2:
            return []

        rows = data_table.find_all("tr")
        notices = []

        for row in rows:
            cells = row.find_all("td")
            if len(cells) < 6:
                continue

            # Cell 4 is notice_identifier — must be numeric
            notice_id = clean_text(cells[4])
            if not extract_numeric_id(notice_id):
                continue

            # Subject is in cell 5; extract link for detail URL
            subject_cell = cells[5]
            subject_text = clean_text(subject_cell)
            subject_link = subject_cell.find("a")

            detail_url = ""
            if subject_link and subject_link.get("href"):
                href = subject_link["href"]
                if href.startswith("http"):
                    detail_url = href
                elif href.startswith("/"):
                    detail_url = f"{base}{href}"
                else:
                    detail_url = f"{base}/{href}"
            if not detail_url:
                detail_url = (
                    f"{base}/MobileInfoPost.aspx"
                    f"?pipeline={pipe_code}&noticeId={notice_id}"
                )

            # Response datetime is cell 6 if present
            response_dt = ""
            if len(cells) >= 7:
                response_dt = clean_text(cells[6])

            notice = {
                "notice_type": clean_text(cells[0]),
                "notice_subtype": "",
                "posted_datetime": clean_text(cells[1]),
                "effective_datetime": clean_text(cells[2]),
                "end_datetime": clean_text(cells[3]),
                "notice_identifier": notice_id,
                "notice_status": "",
                "subject": subject_text,
                "response_datetime": response_dt,
                "detail_url": detail_url,
            }
            notices.append(notice)

        return notices
