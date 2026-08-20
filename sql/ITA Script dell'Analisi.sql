/* PROGETTO: Analisi Energetica e Macroeconomica Mondiale
   OBIETTIVO: Analizzare il rapporto tra PIL e transizione green pre-pandemia (2000-2019)
   METODOLOGIA: L'analisi utilizza il 2019 come anno di riferimento per la 
   completezza dei dati globali rispetto al 2020.
*/

-- PARTE 1: SETUP - Creazione della Vista Analitica
-- Questa vista è il motore del progetto: unisce i dati economici (PIL) 
-- con quelli energetici (Quota Rinnovabili), pulendo i nomi dei paesi.
CREATE OR REPLACE VIEW vista_energia_ricchezza AS
SELECT 
    TRIM(c.country) AS paese, 
    c.gdp AS pil, 
    e.renewable_energy_share AS quota_rinnovabili, 
    e.year AS anno,
    e.latitude, 
    e.longitude
FROM country_stats c
JOIN energy_stats e ON LOWER(TRIM(c.country)) = LOWER(TRIM(e.country))
WHERE e.year = 2019 
  AND c.gdp IS NOT NULL 
  AND e.renewable_energy_share IS NOT NULL;


-- PARTE 2: ANALISI DEI DATI

-- 1. Classifica Globale 2019 (163 Paesi) + Media Mondiale e Posizionamento
SELECT 
    paese, 
    pil, 
    quota_rinnovabili, 
    anno,
    -- Calcolo della media mondiale
    (SELECT ROUND(AVG(quota_rinnovabili), 2) FROM vista_energia_ricchezza) as media_mondiale,
    -- Calcolo del posizionamento
    CASE 
        WHEN quota_rinnovabili > (SELECT AVG(quota_rinnovabili) FROM vista_energia_ricchezza) THEN 'Sopra la Media'
        ELSE 'Sotto la Media'
    END as posizionamento,
    -- Coordinate spostate a destra
    latitude,
    longitude
FROM vista_energia_ricchezza
ORDER BY quota_rinnovabili DESC;
/* RILEVAMENTO: Il dataset finale comprende 163 nazioni. Si osserva una fortissima 
   eterogeneità: si passa da paesi con oltre il 90% di rinnovabili a nazioni 
   quasi totalmente dipendenti dai fossili (sotto il 5%). 
   La media mondiale si attesta al 32.18%. Paesi come l'Italia risultano 
   tecnicamente "Sotto la Media" mondiale perché la media è alzata dai paesi 
   in via di sviluppo che usano quasi esclusivamente biomasse/legna. */

-- 2. Top 10 Paesi Green (Senza filtro PIL)
SELECT * FROM vista_energia_ricchezza ORDER BY quota_rinnovabili DESC LIMIT 10;
/* RILEVAMENTO: La Top 10 è dominata dal continente africano con paesi come 
   Somalia (95%) e Uganda (90%). Questo riflette un'economia energetica basata su 
   risorse naturali e biomasse, piuttosto che su complessi sistemi industriali. */

-- 3. Top 10 Grandi Economie (PIL > 500 Miliardi)
SELECT * FROM vista_energia_ricchezza WHERE pil > 500000000000 ORDER BY quota_rinnovabili DESC LIMIT 10;
/* RILEVAMENTO: Tra i "Big", la Svezia guida con il 52.8%, seguita dal Brasile (47.5%). 
   L'Italia (17.2%) e la Germania (17.1%) mostrano dati quasi identici, 
   superando la Cina (14.4%) nella quota percentuale di rinnovabili sul consumo totale. */

-- 4. Confronto Storico (Focus su paesi chiave)
/* ANALISI DEL TREND STORICO (2000-2019):
   Per questa analisi è stato scelto un arco temporale di circa 20 anni per garantire 
   una visione solida e coerente dell'evoluzione energetica pre-pandemica.
   Per il confronto storico ho scelto i 5 paesi che rappresentano 
   i principali archetipi dello scenario energetico globale:
   
   1. ITALIA & GERMANIA: Rappresentano le grandi economie europee impegnate 
      nella transizione verso obiettivi UE ambiziosi; servono a monitorare 
      l'efficacia delle politiche climatiche continentali.
   2. CINA: Rappresenta il più grande mercato energetico in via di sviluppo; 
      fondamentale per analizzare l'impatto di un'industrializzazione massiccia 
      sulla quota percentuale di rinnovabili.
   3. BRASILE: Rappresenta il benchmark delle energie pulite "naturali"; 
      scelto per osservare come un leader storico mantiene il primato 
      durante la crescita economica moderna.
   4. USA: Scelti come termine di paragone per l'economia globale dominante; 
      permettono di confrontare la velocità della transizione americana 
      rispetto a quella europea e asiatica.
*/

SELECT 
    TRIM(c.country) AS paese,
    e.year AS anno,
    e.renewable_energy_share AS quota_rinnovabili
FROM country_stats c
JOIN energy_stats e ON LOWER(TRIM(c.country)) = LOWER(TRIM(e.country))
-- Intervallo completo per vedere l'evoluzione temporale
WHERE e.year BETWEEN 2000 AND 2019 
  AND TRIM(c.country) IN ('Italy', 'United States', 'China', 'Germany', 'Brazil')
ORDER BY paese, anno;
/* RILEVAMENTO SUI PAESI CHIAVE:
   - ITALIA e GERMANIA: Modelli europei di transizione accelerata; hanno triplicato 
     o quadruplicato la loro quota (Italia +237%, Germania +362%).
   - CINA: Il "paradosso della crescita"; nonostante gli investimenti massicci, 
     la quota percentuale è dimezzata (dal 29% al 14%) perché il consumo totale 
     è cresciuto più velocemente delle installazioni green.
   - BRASILE: Leader consolidato; è passato dal 42.6% al 47.5%. Dimostra come un 
     paese con una base rinnovabile già alta (idroelettrico) riesca a mantenere 
     e migliorare il primato anche durante lo sviluppo industriale.
   - USA: Progresso costante; hanno raddoppiato la quota (dal 5.4% al 10.4%). 
     Riflettono una transizione solida ma più graduale rispetto ai partner europei.
*/

--5 ANALISI TOP 3 ACCELERATORI PER CONTINENTE "GREEN SPRINTERS"
/* - Utilizzo le coordinate geografiche per mappare i 163 paesi.
   - Uso FIRST_VALUE per trovare il primo anno utile dal 2000.
   - Uso LAST_VALUE (o MAX sull'anno) per il 2019.
   - Calcolo l'accelerazione indipendentemente dall'anno di partenza.
   - RANK() per isolare i 3 migliori incrementi per ogni macro-area/continente.
*/
WITH serie_storica AS (
    SELECT 
        TRIM(e.country) as paese,
        e.year,
        e.renewable_energy_share as quota,
        -- Mapping automatico basato su coordinate spaziali precise
        CASE 
            WHEN e.latitude > 34 AND e.longitude BETWEEN -25 AND 45 THEN 'Europa'
            WHEN e.latitude BETWEEN -35 AND 35 AND e.longitude BETWEEN -20 AND 52 THEN 'Africa'
            WHEN e.longitude BETWEEN -170 AND -30 THEN 'Americhe'
            WHEN e.longitude > 110 AND e.latitude < 22 THEN 'Oceania'
            WHEN e.longitude < -170 AND e.latitude < 22 THEN 'Oceania'
            ELSE 'Asia' 
        END as continente,
        FIRST_VALUE(e.renewable_energy_share) OVER (
            PARTITION BY e.country ORDER BY e.year ASC 
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) as quota_inizio,
        FIRST_VALUE(e.renewable_energy_share) OVER (
            PARTITION BY e.country ORDER BY e.year DESC 
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) as quota_fine
    FROM energy_stats e
    WHERE e.year BETWEEN 2000 AND 2019
),
calcolo_incremento AS (
    SELECT DISTINCT
        paese,
        continente,
        quota_inizio,
        quota_fine,
        (quota_fine - quota_inizio) as accelerazione
    FROM serie_storica
),
ranking_finale AS (
    SELECT 
        continente,
        paese,
        ROUND(accelerazione, 2) as incremento_percentuale,
        RANK() OVER (PARTITION BY continente ORDER BY accelerazione DESC) as rank_sprinter
    FROM calcolo_incremento
    WHERE accelerazione > 0
)
SELECT * FROM ranking_finale 
WHERE rank_sprinter <= 3
ORDER BY continente, rank_sprinter;
/*
1. EUROPA LEADER DI TRANSIZIONE: La Danimarca (+26.79%) è il benchmark mondiale per 
   velocità di cambiamento, seguita dall'Islanda che, pur partendo alta, ha saputo 
   incrementare ulteriormente (+20.41%).

2. IL "CASO URUGUAY": Nelle Americhe spicca l'Uruguay (+22.03%), un esempio di come 
   politiche mirate possano stravolgere il mix energetico nazionale in un ventennio.

3. ACCELERAZIONE INSULARE (OCEANIA): Tuvalu (+8.20%) guida l'Oceania. Questo dato è 
   fondamentale: per le piccole isole, la transizione non è solo ecologia ma 
   sicurezza energetica contro l'innalzamento dei mari.

4. ASIA E AFRICA: Notiamo incrementi più contenuti (Gabon +17.10%, Giappone +3.99%). 
   In Asia la crescita della quota è frenata dall'esplosione della domanda totale, 
   mentre il Gabon dimostra che l'Africa resta sempre vincolata alle biomasse tradizionali.
*/