/* PROJECT: Global Energy and Macroeconomic Analysis
   OBJECTIVE: Analyze the relationship between GDP and the green transition pre-pandemic (2000-2019)
   METHODOLOGY: The analysis uses 2019 as the reference year due to the 
   completeness of global data compared to 2020.
*/

-- PART 1: SETUP - Analytical View Creation
-- This view is the core of the project: it merges economic data (GDP) 
-- with energy data (Renewables Share), cleaning up country names.
CREATE OR REPLACE VIEW energy_wealth_view AS
SELECT 
    TRIM(c.country) AS country, 
    c.gdp AS gdp, 
    e.renewable_energy_share AS renewable_share, 
    e.year AS year,
    e.latitude, 
    e.longitude
FROM country_stats c
JOIN energy_stats e ON LOWER(TRIM(c.country)) = LOWER(TRIM(e.country))
WHERE e.year = 2019 
  AND c.gdp IS NOT NULL 
  AND e.renewable_energy_share IS NOT NULL;

  
  -- PART 2: DATA ANALYSIS

-- 1. 2019 Global Ranking (163 Countries) + World Average and Positioning
SELECT 
    country, 
    gdp, 
    renewable_share, 
    year,
    -- Global average calculation
    (SELECT ROUND(AVG(renewable_share), 2) FROM energy_wealth_view) as global_average,
    -- Positioning calculation
    CASE 
        WHEN renewable_share > (SELECT AVG(renewable_share) FROM energy_wealth_view) THEN 'Above Average'
        ELSE 'Below Average'
    END as positioning,
    -- Coordinates shifted to the right
    latitude,
    longitude
FROM energy_wealth_view
ORDER BY renewable_share DESC;

/* FINDINGS: The final dataset includes 163 nations. Significant heterogeneity is observed: 
   values range from countries with over 90% renewable energy to nations almost 
   entirely dependent on fossil fuels (below 5%). 
   The global average stands at 32.18%. Countries like Italy are technically 
   ranked "Below the Global Average" because the mean is skewed upward by 
   developing nations that rely almost exclusively on biomass/wood. */

-- 2. Top 10 Greenest Countries (Unfiltered by GDP)
SELECT * FROM energy_wealth_view ORDER BY renewable_share DESC LIMIT 10;

/* FINDINGS: The Top 10 is dominated by the African continent, featuring countries 
   such as Somalia (95%) and Uganda (90%). This reflects an energy economy 
   based on natural resources and biomass rather than complex industrial systems. */

-- 3. Top 10 Large Economies (GDP > 500 Billion)
SELECT * FROM energy_wealth_view WHERE gdp > 500000000000 ORDER BY renewable_share DESC LIMIT 10;

/* FINDINGS: Among the "Big" economies, Sweden leads with 52.8%, followed by Brazil (47.5%). 
   Italy (17.2%) and Germany (17.1%) show nearly identical figures, 
   surpassing China (14.4%) in the percentage share of renewables relative to total consumption. */


-- 4. Historical Comparison (Focus on Key Countries)
/* HISTORICAL TREND ANALYSIS (2000-2019):
   A timeframe of approximately 20 years was selected for this analysis to ensure 
   a robust and consistent view of pre-pandemic energy evolution.
   Five countries representing the primary archetypes of the global energy 
   landscape were chosen for the historical comparison:
   
   1. ITALY & GERMANY: Represent large European economies committed to the green 
      transition under ambitious EU targets; they serve to monitor the 
      effectiveness of continental climate policies.
   2. CHINA: Represents the largest developing energy market; essential for 
      analyzing the impact of massive industrialization on the renewable energy share.
   3. BRAZIL: Represents the benchmark for "natural" clean energy; chosen to 
      observe how a historical leader maintains dominance during modern 
      economic growth.
   4. USA: Selected as the baseline for the dominant global economy; allows for 
      comparing the pace of the American transition against European and Asian counterparts.
*/

SELECT 
    TRIM(c.country) AS country,
    e.year AS year,
    e.renewable_energy_share AS renewable_share
FROM country_stats c
JOIN energy_stats e ON LOWER(TRIM(c.country)) = LOWER(TRIM(e.country))
-- Full range to observe temporal evolution
WHERE e.year BETWEEN 2000 AND 2019 
  AND TRIM(c.country) IN ('Italy', 'United States', 'China', 'Germany', 'Brazil')
ORDER BY country, year;

/* FINDINGS ON KEY COUNTRIES:
   - ITALY & GERMANY: European models of accelerated transition; they tripled 
     or quadrupled their share (Italy +237%, Germany +362%).
   - CHINA: The "Growth Paradox"; despite massive investments, the percentage 
     share was halved (from 29% to 14%) because total consumption grew 
     faster than green installations.
   - BRAZIL: Established leader; increased from 42.6% to 47.5%. Demonstrates how 
     a country with a high renewable baseline (hydroelectric) can maintain 
     and improve its lead even during industrial development.
   - USA: Steady progress; doubled its share (from 5.4% to 10.4%). 
     Reflects a solid but more gradual transition compared to European partners.
*/

-- 5. TOP 3 ACCELERATORS BY CONTINENT "GREEN SPRINTERS"
/* - Using geographic coordinates to map the 163 countries.
   - Using FIRST_VALUE to identify the first available year starting from 2000.
   - Using LAST_VALUE (or MAX on the year) for 2019.
   - Calculating acceleration regardless of the starting year.
   - Using RANK() to isolate the top 3 increases for each macro-region/continent.
*/

WITH historical_series AS (
    SELECT 
        TRIM(e.country) as country,
        e.year,
        e.renewable_energy_share as share,
        -- Automatic mapping based on precise spatial coordinates
        CASE 
            WHEN e.latitude > 34 AND e.longitude BETWEEN -25 AND 45 THEN 'Europe'
            WHEN e.latitude BETWEEN -35 AND 35 AND e.longitude BETWEEN -20 AND 52 THEN 'Africa'
            WHEN e.longitude BETWEEN -170 AND -30 THEN 'Americas'
            WHEN e.longitude > 110 AND e.latitude < 22 THEN 'Oceania'
            WHEN e.longitude < -170 AND e.latitude < 22 THEN 'Oceania'
            ELSE 'Asia' 
        END as continent,
        FIRST_VALUE(e.renewable_energy_share) OVER (
            PARTITION BY e.country ORDER BY e.year ASC 
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) as start_share,
        FIRST_VALUE(e.renewable_energy_share) OVER (
            PARTITION BY e.country ORDER BY e.year DESC 
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) as end_share
    FROM energy_stats e
    WHERE e.year BETWEEN 2000 AND 2019
),
increment_calculation AS (
    SELECT DISTINCT
        country,
        continent,
        start_share,
        end_share,
        (end_share - start_share) as acceleration
    FROM historical_series
),
final_ranking AS (
    SELECT 
        continent,
        country,
        ROUND(acceleration, 2) as percentage_increase,
        RANK() OVER (PARTITION BY continent ORDER BY acceleration DESC) as sprinter_rank
    FROM increment_calculation
    WHERE acceleration > 0
)
SELECT * FROM final_ranking 
WHERE sprinter_rank <= 3
ORDER BY continent, sprinter_rank;

/*
1. EUROPE AS TRANSITION LEADER: Denmark (+26.79%) is the global benchmark for 
   speed of change, followed by Iceland, which managed to further increase 
   its share (+20.41%) despite already starting from a high baseline.

2. THE "URUGUAY CASE": In the Americas, Uruguay stands out (+22.03%), serving 
   as an example of how targeted policies can overhaul a national energy 
   mix within two decades.

3. INSULAR ACCELERATION (OCEANIA): Tuvalu (+8.20%) leads Oceania. This data is 
   critical: for small islands, the transition is not just about ecology but 
   about energy security against rising sea levels.

4. ASIA AND AFRICA: We observe more moderate increases (Gabon +17.10%, Japan +3.99%). 
   In Asia, the share growth is hampered by the explosion in total demand, 
   while Gabon demonstrates that Africa remains heavily tied to traditional biomass.
*/