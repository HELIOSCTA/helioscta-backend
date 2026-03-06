// @ts-check
const { themes } = require("prism-react-renderer");

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: "HeliosCTA Docs",
  tagline: "Data catalog, pipelines, and dbt views",
  // favicon: "img/favicon.ico",

  url: "https://helioscta-backend.vercel.app",
  baseUrl: "/",

  organizationName: "akeavenyhelioscta",
  projectName: "helioscta-backend",

  onBrokenLinks: "throw",

  markdown: {
    hooks: {
      onBrokenMarkdownLinks: "throw",
    },
  },

  presets: [
    [
      "classic",
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          routeBasePath: "/",
          sidebarPath: require.resolve("./sidebars.js"),
          editUrl:
            "https://github.com/akeavenyhelioscta/helioscta-backend/edit/main/",
        },
        blog: false,
        theme: {
          customCss: require.resolve("./src/css/custom.css"),
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      colorMode: {
        defaultMode: "dark",
        respectPrefersColorScheme: true,
      },
      navbar: {
        title: "HeliosCTA Docs",
        items: [
          {
            href: "https://github.com/akeavenyhelioscta/helioscta-backend",
            label: "GitHub",
            position: "right",
          },
        ],
      },
      footer: {
        style: "dark",
        copyright: `HeliosCTA ${new Date().getFullYear()}`,
      },
      prism: {
        theme: themes.github,
        darkTheme: themes.dracula,
        additionalLanguages: ["sql", "bash"],
      },
    }),
};

module.exports = config;
