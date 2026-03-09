/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  docs: [
    {
      type: "doc",
      id: "README",
      label: "Home",
    },
    {
      type: "doc",
      id: "dbt-cleaned-catalog",
      label: "Data Catalog",
    },
    {
      type: "category",
      label: "Weather (WSI)",
      collapsed: true,
      items: [
        {
          type: "doc",
          id: "domains/wsi/overview",
          label: "Overview",
        },
        {
          type: "doc",
          id: "domains/wsi/scrapes/wsi-scrapes",
          label: "Scrapes",
        },
        {
          type: "doc",
          id: "domains/wsi/dbt-views/wsi-cleaned",
          label: "dbt Views",
        },
      ],
    },
    {
      type: "category",
      label: "Power",
      collapsed: true,
      items: [
        {
          type: "doc",
          id: "domains/power/overview",
          label: "Overview",
        },
        {
          type: "category",
          label: "Scrapes",
          items: [
            {
              type: "doc",
              id: "domains/power/scrapes/pjm-da-hrl-lmps",
              label: "DA LMPs",
            },
            {
              type: "doc",
              id: "domains/power/scrapes/pjm-rt-unverified-lmps",
              label: "RT LMPs (Unverified)",
            },
            {
              type: "doc",
              id: "domains/power/scrapes/pjm-rt-verified-lmps",
              label: "RT LMPs (Verified)",
            },
            {
              type: "doc",
              id: "domains/power/scrapes/pjm-hourly-load-metered",
              label: "Load (Metered)",
            },
            {
              type: "doc",
              id: "domains/power/scrapes/pjm-hourly-load-prelim",
              label: "Load (Prelim)",
            },
            {
              type: "doc",
              id: "domains/power/scrapes/pjm-five-min-load",
              label: "Load (5-Min)",
            },
            {
              type: "doc",
              id: "domains/power/scrapes/pjm-hrl-dmd-bids",
              label: "DA Demand Bids",
            },
            {
              type: "doc",
              id: "domains/power/scrapes/pjm-seven-day-load-forecast",
              label: "Load Forecast",
            },
            {
              type: "doc",
              id: "domains/power/scrapes/pjm-seven-day-outage-forecast",
              label: "Outage Forecast",
            },
            {
              type: "doc",
              id: "domains/power/scrapes/pjm-five-min-tie-flows",
              label: "Tie Flows",
            },
            {
              type: "doc",
              id: "domains/power/scrapes/gridstatus-overview",
              label: "GridStatus",
            },
          ],
        },
        {
          type: "doc",
          id: "domains/power/dbt-views/pjm-cleaned",
          label: "dbt Views",
        },
      ],
    },
    {
      type: "category",
      label: "Meteologica",
      collapsed: true,
      items: [
        {
          type: "doc",
          id: "domains/meteologica/overview",
          label: "Overview",
        },
        {
          type: "doc",
          id: "domains/meteologica/scrapes/meteologica-scrapes",
          label: "Scrapes",
        },
        {
          type: "doc",
          id: "domains/meteologica/dbt-views/meteologica-cleaned",
          label: "dbt Views",
        },
      ],
    },
    {
      type: "category",
      label: "EIA",
      collapsed: true,
      items: [
        {
          type: "doc",
          id: "domains/eia/overview",
          label: "Overview",
        },
        {
          type: "doc",
          id: "domains/eia/scrapes/eia-scrapes",
          label: "Scrapes",
        },
        {
          type: "doc",
          id: "domains/eia/dbt-views/eia-cleaned",
          label: "dbt Views",
        },
      ],
    },
    {
      type: "category",
      label: "Genscape",
      collapsed: true,
      items: [
        {
          type: "doc",
          id: "domains/genscape/overview",
          label: "Overview",
        },
        {
          type: "doc",
          id: "domains/genscape/scrapes/genscape-scrapes",
          label: "Scrapes",
        },
        {
          type: "doc",
          id: "domains/genscape/dbt-views/genscape-cleaned",
          label: "dbt Views",
        },
      ],
    },
    {
      type: "category",
      label: "Positions & Trades",
      collapsed: true,
      items: [
        {
          type: "doc",
          id: "domains/positions-and-trades/overview",
          label: "Overview",
        },
        {
          type: "doc",
          id: "domains/positions-and-trades/scrapes/positions-and-trades-scrapes",
          label: "Scrapes",
        },
        {
          type: "doc",
          id: "domains/positions-and-trades/dbt-views/positions-and-trades-cleaned",
          label: "dbt Views",
        },
      ],
    },
  ],
};

module.exports = sidebars;
