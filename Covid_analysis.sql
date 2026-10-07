-- COVID-19 ANALYSIS --

-- DATA EXPLORATION --

SELECT *
FROM dbo.CovidDeaths;

SELECT *
FROM dbo.CovidVaccinations;

SELECT *
FROM dbo.ibovespa;

-- TOTAL CASES vs TOTAL DEATHS BY LOCATION --

-- Worldwide
SELECT location, date, total_cases, total_deaths, (total_deaths/total_cases) * 100 AS death_percentage
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
ORDER BY location, date;

-- Brazil
SELECT location, date, total_cases, total_deaths, (total_deaths/total_cases) * 100 AS death_percentage
FROM dbo.CovidDeaths
WHERE location = 'Brazil'
ORDER BY date;

-- TOTAL CASES vs POPULATION BY LOCATION --

-- Worldwide
SELECT location, date, total_cases, population, (total_cases/population) * 100 AS populationinfected_percentage
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
ORDER BY location, date;

-- Brazil
SELECT location, date, total_cases, population, (total_cases/population) * 100 AS populationinfected_percentage
FROM dbo.CovidDeaths
WHERE location = 'Brazil'
ORDER BY date;

-- COUNTRIES WITH HIGHEST INFECTION PERCENTAGE COMPARED TO POPULATION --

SELECT location, population, MAX(total_cases) AS total_cases, MAX((total_cases/population)) * 100 AS total_population_infected
FROM dbo.CovidDeaths
WHERE location IS NOT NULL
GROUP BY location, population
ORDER BY total_population_infected DESC;

-- OVERALL HIGHEST INFECTION PERCENTAGE IN BRAZIL --

SELECT location, population, MAX(total_cases) AS total_cases, MAX((total_cases/population)) * 100 AS total_population_infected
FROM dbo.CovidDeaths
WHERE location = 'Brazil'
GROUP BY location, population
ORDER BY total_population_infected DESC;

-- HIGHEST DEATH COUNT PER POPULATION AND DEATH PERCENTAGE --

-- Worldwide
SELECT location, population, MAX(total_deaths) AS total_deaths, (MAX(total_deaths)/population) * 100 AS death_percentage_by_population
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY death_percentage_by_population DESC;

-- Brazil
SELECT location, population, MAX(total_deaths) AS total_deaths, (MAX(total_deaths)/population) * 100 AS death_percentage_by_population
FROM dbo.CovidDeaths
WHERE location = 'Brazil'
GROUP BY location, population
ORDER BY death_percentage_by_population DESC;

-- ANALYSIS BY CONTINENT USING TEMP TABLE --

CREATE TABLE #bycontinent (
continent VARCHAR (100),
population FLOAT,
total_cases FLOAT,
total_deaths FLOAT,
total_population_infected FLOAT,
total_death_percentage FLOAT 
);

INSERT INTO #bycontinent
SELECT location, population,
MAX(total_cases)  AS total_cases,
MAX(total_deaths) AS total_deaths,
(MAX(CAST(total_cases AS FLOAT)) / NULLIF(population, 0)) * 100 AS total_population_infected,
(MAX(CAST(total_deaths AS FLOAT)) / NULLIF(MAX(CAST(total_cases AS FLOAT)), 0)) * 100 AS total_death_percentage
FROM dbo.CovidDeaths
WHERE continent IS NULL
AND location NOT IN ('World', 'International', 'European Union')
GROUP BY location, population;

SELECT *
FROM #bycontinent
ORDER BY total_deaths DESC;

-- ROLLING VACCINATIONS BY COUNTRY AND DATE --

-- Worldwide
SELECT d.continent, d.location, d.date, d.population, v.new_vaccinations, 
SUM(v.new_vaccinations) OVER (PARTITION BY d.location ORDER BY d.location, d.date) AS rolling_vaccinations
FROM dbo.CovidDeaths AS d
JOIN dbo.CovidVaccinations AS v
 ON d.location = v.location 
 AND d.date = v.date
WHERE d.continent IS NOT NULL
ORDER BY d.location, d.date;

-- BRAZIL'S ROLLING VACCINATIONS BY DATE USING CTE --

WITH vaccination_per_population (continent, location, date, population, new_vaccinations, rolling_vaccinations) AS
(
SELECT d.continent, d.location, d.date, d.population, v.new_vaccinations, 
 SUM(v.new_vaccinations) OVER (PARTITION BY d.location ORDER BY d.location, d.date) 
  AS rolling_vaccinations
FROM dbo.CovidDeaths AS d
JOIN dbo.CovidVaccinations AS v
 ON d.location = v.location 
AND d.date = v.date
WHERE d.continent IS NOT NULL AND d.location = 'Brazil'
)
SELECT*, (rolling_vaccinations/population)*100 AS vaccination_per_population
FROM vaccination_per_population;

-- ANALYSIS OF THE IMPACT OF COVID-19 ON THE IBOVESPA --

-- INFECTION, DEATHS AND IBOVESPA --

-- Early pandemic (Feb 26 - May 3, 2020)
SELECT d.date, d.location, d.total_cases, d.total_deaths, 
(d.total_cases / d.population) * 100  AS population_infected_percentage, 
(d.total_deaths / d.population) * 100 AS deaths_percentage, 
i.[Close] AS ibovespa_close
FROM dbo.CovidDeaths AS d
LEFT JOIN dbo.ibovespa AS i 
ON d.date = i.[Date]
WHERE d.location = 'Brazil'
AND d.date BETWEEN '2020-02-26' AND '2020-05-03'
ORDER BY d.date;

-- Second wave (Jan 1 - Jun 30, 2021): new cases, new deaths and Ibovespa
SELECT d.date, location, new_cases, total_cases, new_deaths, total_deaths, 
(total_cases/population) * 100 AS population_infected_percentage,  
(total_deaths/population) * 100 AS deaths_percentage, 
i.[Close] AS ibovespa_close
FROM dbo.CovidDeaths AS d
LEFT JOIN dbo.ibovespa AS i
ON d.date = i.[Date]
WHERE d.location = 'Brazil'
AND d.date BETWEEN '2021-01-01' AND '2021-06-30'
ORDER BY new_deaths DESC;

-- TOP 10 LOWEST IBOVESPA CLOSING VALUES vs COVID-19 NUMBERS --

WITH i AS (
SELECT date, [close] AS ibovespa_close
FROM dbo.ibovespa
)
SELECT TOP 10 d.date, d.new_cases, total_cases, new_deaths, total_deaths, i.ibovespa_close
FROM dbo.CovidDeaths AS d
JOIN i
  ON d.date = i.date
WHERE d.location = 'Brazil'
ORDER BY ibovespa_close ASC;

-- VACCINATION RATE vs IBOVESPA CLOSE --

-- Once vaccination rate exceeds 1%
SELECT v.date, v.location, v.new_vaccinations, v.total_vaccinations, (v.total_vaccinations/d.population) * 100 AS vaccination_rate, i.[close]
FROM dbo.CovidVaccinations AS v
JOIN dbo.CovidDeaths AS d
ON v.location = d.location AND v.date = d.date
LEFT JOIN dbo.ibovespa AS i
ON v.date = i.date 
WHERE v.location = 'Brazil' 
AND (v.total_vaccinations/d.population) * 100 > 1 
ORDER BY v.date DESC;