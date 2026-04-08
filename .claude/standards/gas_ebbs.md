# Gas EBB Scraping Preferences

## Source Hierarchy

**Always prefer the direct pipeline EBB over an aggregator like PipeRiv.** Direct EBBs provide:
- Full datetime precision (timestamps vs truncated dates)
- Non-critical notices (PipeRiv only shows critical)
- Authoritative data (PipeRiv aggregates from these EBBs with potential lag)

When both a direct EBB and PipeRiv are available for a pipeline, scrape both but tag with `source_family` so consumers can filter. Direct EBB is the canonical source; PipeRiv is the fallback/cross-validation source.

## Notice Types to Capture

Capture **all available notice types**, not just critical. At minimum:
- **CRI** -- Critical notices (capacity constraints, OFOs, force majeures)
- **NON** -- Non-critical notices (timely cycle volumes, training, invoices)

Additional types where available: OUT (planned outages), OPN (open seasons), GQW (gas quality waivers).

## NAESB Pipeline EBB Directory

Full list: https://www.naesb.org/members/urls_of_pipelines.htm

**135 pipelines** configured across **15 source families**.

### EBB Platforms by Operator

#### Enbridge LINK -- `infopost.enbridge.com` (adapter: `enbridge`, 18 pipelines)

| Pipeline | Pipe Code | Status |
|---|---|---|
| Algonquin Gas Transmission (AGT) | AG | Implemented + Tested |
| Texas Eastern Transmission (TE) | TE | Implemented + Tested |
| East Tennessee Natural Gas (ETNG) | ETNG | Implemented + Tested |
| Southeast Supply Header (SESH) | SESH | Implemented + Tested |
| Sabal Trail Transmission (STT) | STT | Implemented + Tested |
| NEXUS U.S. (NXUS) | NXUS | Implemented + Tested |
| Maritimes & Northeast U.S. (MNUS) | MNUS | Implemented |
| Big Sandy Pipeline (BSP) | BSP | Implemented |
| Saltville Gas Storage (SGSC) | SGSC | Implemented |
| Steckman Ridge (SR) | SR | Implemented |
| Valley Crossing Pipeline (VCP) | VCP | Implemented |
| Bobcat Gas Storage (BGS) | BGS | Implemented |
| Egan Hub Storage (EHP) | EHP | Implemented |
| Garden Banks (GB) | GB | Implemented |
| Mississippi Canyon (MCGP) | MCGP | Implemented |
| Moss Bluff Hub (MBHP) | MBHP | Implemented |
| Nautilus Pipeline (NPC) | NPC | Implemented |
| Tres Palacios Gas Storage (TPGS) | TPGS | Implemented |

#### Kinder Morgan -- `pipeline2.kindermorgan.com` (adapter: `kindermorgan`, 19 pipelines)

Infragistics WebDataGrid. Parses server-rendered HTML `<tr>` rows with 9 `<td>` cells.
Tested: TGP (75 notices), SNG (75 notices).

| Pipeline | Code | Status |
|---|---|---|
| Tennessee Gas Pipeline | TGP | Tested |
| Southern Natural Gas | SNG | Tested |
| Natural Gas Pipeline of America | NGPL | Implemented |
| El Paso Natural Gas | EPNG | Implemented |
| Colorado Interstate Gas | CIG | Implemented |
| Cheyenne Plains | CP | Implemented |
| Elba Express | EEC | Implemented |
| Midcontinent Express | MEP | Implemented |
| Mojave Pipeline | MOPC | Implemented |
| Sierrita Gas Pipeline | SGP | Implemented |
| TransColorado | TCP | Implemented |
| Wyoming Interstate | WIC | Implemented |
| Southern LNG | SLNG | Implemented |
| Kinder Morgan Illinois | KMIL | Implemented |
| Kinder Morgan Louisiana | KMLP | Implemented |
| Horizon Pipeline | HORZ | Implemented |
| Stagecoach | STAG | Implemented |
| Arlington Storage | ARLS | Implemented |
| Young Gas Storage | YGS | Implemented |

#### TC Energy -- `tceconnects.com` (adapter: `tce`, 11 pipelines)

JavaScript SPA. Adapter tries JSON API first, falls back to HTML table parsing.

| Pipeline | Code |
|---|---|
| ANR Pipeline Company | ANR |
| ANR Storage Company | ANRS |
| Bison Pipeline | BISON |
| Blue Lake Gas Storage | BLGS |
| Columbia Gas Transmission | TCO |
| Columbia Gulf Transmission | CGUL |
| Crossroads Pipeline | CROSS |
| Hardy Storage | HARDY |
| Millennium Pipeline | MILL |
| Northern Border Pipeline | NBPL |
| Portland Natural Gas Transmission | PNGTS |

#### Williams 1Line -- `1line.williams.com` (adapter: `williams`, 5 pipelines)

Frame-based HTML. Parses tables from info-postings/notices pages.

| Pipeline | Base URL |
|---|---|
| Transco | 1line.williams.com/Transco |
| Northwest Pipeline | 1line.williams.com/Northwest |
| Gulfstream Natural Gas | 1line.gulfstreamgas.com |
| Discovery Gas Transmission | discovery.williams.com |
| Pine Needle LNG | pineneedle.williams.com |

#### Energy Transfer -- various subdomains (adapter: `energytransfer`, 9 pipelines)

Quorum-based platform. Each pipeline has own subdomain.

| Pipeline | Domain | Code |
|---|---|---|
| Florida Gas Transmission | fgttransfer.energytransfer.com | fgt |
| Panhandle Eastern | peplmessenger.energytransfer.com | pepl |
| Transwestern | twtransfer.energytransfer.com | tw |
| Trunkline Gas | tgcmessenger.energytransfer.com | tgc |
| Sea Robin | sermessenger.energytransfer.com | ser |
| Tiger Pipeline | tigertransfer.energytransfer.com | tgr |
| Fayetteville Express | feptransfer.energytransfer.com | fep |
| Trunkline LNG | tlngmessenger.energytransfer.com | tlng |
| Southwest Gas Storage | swgsmessenger.energytransfer.com | swgs |

#### TC Plus -- `tcplus.com` (adapter: `tcplus`, 4 pipelines)

HTML table with CSS class-based cell identification. Tested: GTN (0 notices at time of test).

| Pipeline | Path |
|---|---|
| Gas Transmission Northwest | gtn |
| Great Lakes Gas Transmission | great%20lakes |
| Tuscarora Gas Transmission | tuscarora |
| North Baja Pipeline | north%20baja |

#### BHEGTS / Dominion -- `infopost.bhegts.com` (adapter: `bhegts`, 3 pipelines)

Next.js SSR. Parses embedded JSON postings from `__NEXT_DATA__` script.
Tested: EGTS (80 notices).

| Pipeline | Code |
|---|---|
| Carolina Gas Transmission | cgt |
| Cove Point LNG | cpl |
| Eastern Gas Transmission & Storage | egts |

#### Quorum / MyQuorumCloud -- `web-prd.myquorumcloud.com` (adapter: `quorum`, 7 pipelines)

Kendo Grid. Tries JSON API via POST, falls back to HTML table parsing.

| Pipeline | App Code | TSP No |
|---|---|---|
| BBT (AlaTenn) | BBTPA1IPWS | 3 |
| BBT (Midla) | BBTPA1IPWS | 6 |
| BBT (Trans-Union) | BBTPA1IPWS | 12 |
| Ozark Gas Transmission | BBTPA1IPWS | 16 |
| High Point Gas Transmission | HPEPA1IPWS | 1 |
| Chandeleur Pipe Line | HPEPA1IPWS | 14 |
| Destin Pipeline | HPEPA1IPWS | 9 |

#### Northern Natural Gas -- `northernnaturalgas.com` (adapter: `northern_natural`, 1 pipeline)

Telerik RadGrid, server-rendered HTML. Tested: 2 critical notices.

#### DT Midstream -- `dtmidstream.trellisenergy.com` (adapter: `dtmidstream`, 3 pipelines)

Trellis Energy portal. Parses `notice-event-link` elements with `data-noticesdata` JSON attributes.

| Pipeline | TSP Code |
|---|---|
| Guardian Pipeline | GPL |
| Midwestern Gas Transmission | mgt |
| Viking Gas Transmission | vgt |

#### Tallgrass -- `pipeline.tallgrassenergylp.com` (adapter: `tallgrass`, 4 pipelines)

Likely requires JavaScript/Selenium. Skeleton adapter with HTML table fallback.

| Pipeline |
|---|
| Rockies Express Pipeline (REX) |
| Ruby Pipeline |
| Tallgrass Interstate Gas Transmission |
| Trailblazer Pipeline |

#### GasNom -- `gasnom.com` (adapter: `gasnom`, 6 pipelines)

Generic HTML table parsing.

| Pipeline | Path |
|---|---|
| Southern Pines | /ip/SOUTHERNPINES/ |
| Cameron Interstate | /ip/cameron |
| Golden Pass | /ip/goldenpass |
| Golden Triangle Storage | /ip/goldentriangle/ |
| Mississippi Hub | /ip/mississippihub |
| LA Storage | /ip/lastorage |

#### Cheniere -- `lngconnection.cheniere.com` (adapter: `cheniere`, 3 pipelines)

React SPA. Adapter attempts JSON API discovery with multiple URL patterns.

| Pipeline | Hash Route |
|---|---|
| Corpus Christi Pipeline | #/ccpl |
| Creole Trail Pipeline | #/ctpl |
| Midship Pipeline | #/mspl |

#### PipeRiv -- `piperiv.com` (adapter: `piperiv`, aggregator, 14 pipelines)

PipeRiv is an aggregator that mirrors notices from direct EBBs. Use as fallback only.

#### Standalone -- various domains (adapter: `standalone`, 28 pipelines)

Generic fallback adapter for pipelines with unique EBBs. Attempts to find and parse the largest HTML table on each page.

Includes: Iroquois, Gulf South, Southern Star, Texas Gas, Sabine, Empire, National Fuel, Enable Gas/MRT, Enterprise (HIOS/Petal), Kern River, WBI Energy, Alliance, Florida Southeast, Black Marlin, MountainWest, Paiute, Boardwalk Storage, DCP (Cimarron/Dauphin), Vector, Stingray, KO Transmission, WestGas, White River Hub, ONEOK OkTex.
