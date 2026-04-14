/*
Project: Smart Device Usage Analysis – Fitness Tracker Dataset
Author: Mbali Radebe
Tools: MySQL
Dataset: FitBit Fitness Tracker Data (Bellabeat Case Study Context)

Description:
This script cleans, transforms, and analyzes smart device data to uncover 
trends in user activity, sleep patterns, and engagement levels. 
The goal is to provide data-driven recommendations for wellness product marketing.
*/

-- ============================================
-- STEP 1: ENVIRONMENT SETUP & DATA PREVIEW
-- ============================================

-- Preview initial datasets to understand schema
SELECT * FROM dailyactivity_merged LIMIT 5;
SELECT * FROM minuteSleep_merged LIMIT 5;


-- ============================================
-- STEP 2: DATA CLEANING (DAILY ACTIVITY)
-- ============================================

DROP TABLE IF EXISTS daily_clean;

CREATE TABLE daily_clean AS
SELECT
    Id,
    STR_TO_DATE(ActivityDate, '%m/%d/%Y') AS ActivityDate,
    TotalSteps,
    TotalDistance,
    VeryActiveMinutes,
    FairlyActiveMinutes,
    LightlyActiveMinutes,
    SedentaryMinutes,
    Calories
FROM dailyactivity_merged;

-- Add Primary Key/Index for optimization during joins
ALTER TABLE daily_clean ADD INDEX (Id, ActivityDate);


-- ============================================
-- STEP 3: DATA CLEANING (SLEEP DATA)
-- ============================================

/* We convert minute-level sleep data into a daily aggregate.
   Note: Value '1' usually represents 'asleep' in this dataset.
*/
DROP TABLE IF EXISTS sleep_daily;

CREATE TABLE sleep_daily AS
SELECT
    Id,
    DATE(STR_TO_DATE(date, '%m/%d/%Y %r')) AS SleepDate,
    SUM(value) AS TotalMinutesAsleep,
    COUNT(value) AS TotalTimeInBed -- Assuming every record is time in bed
FROM minuteSleep_merged
GROUP BY Id, SleepDate;

ALTER TABLE sleep_daily ADD INDEX (Id, SleepDate);


-- ============================================
-- STEP 4: DATA INTEGRATION
-- ============================================

DROP TABLE IF EXISTS combined_data;

CREATE TABLE combined_data AS
SELECT
    d.Id,
    d.ActivityDate,
    DAYNAME(d.ActivityDate) AS DayOfWeek, -- Added for easier time-series analysis
    d.TotalSteps,
    d.Calories,
    d.SedentaryMinutes,
    d.VeryActiveMinutes,
    s.TotalMinutesAsleep
FROM daily_clean d
LEFT JOIN sleep_daily s
    ON d.Id = s.Id 
    AND d.ActivityDate = s.SleepDate;


-- ============================================
-- STEP 5: BUSINESS INSIGHTS & ANALYSIS
-- ============================================

-- 1. Activity Distribution (User Segmentation)
-- Categorizing users based on the CDC's general step-count guidelines
SELECT
    CASE
        WHEN TotalSteps < 5000 THEN 'Sedentary/Inactive'
        WHEN TotalSteps BETWEEN 5000 AND 7499 THEN 'Lightly Active'
        WHEN TotalSteps BETWEEN 7500 AND 9999 THEN 'Fairly Active'
        ELSE 'Highly Active (10k+)'
    END AS ActivityLevel,
    COUNT(*) AS TotalDays,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM combined_data), 2) AS Percentage
FROM combined_data
GROUP BY ActivityLevel
ORDER BY TotalDays DESC;


-- 2. Correlation: Does more activity lead to better sleep?
SELECT
    CASE
        WHEN TotalSteps < 5000 THEN 'Low Activity'
        WHEN TotalSteps BETWEEN 5000 AND 10000 THEN 'Moderate Activity'
        ELSE 'High Activity'
    END AS ActivityGroup,
    ROUND(AVG(TotalMinutesAsleep), 2) AS AvgSleepMinutes,
    ROUND(AVG(TotalMinutesAsleep)/60, 2) AS AvgSleepHours
FROM combined_data
WHERE TotalMinutesAsleep IS NOT NULL
GROUP BY ActivityGroup;


-- 3. Day of the Week Trends
-- Identifies which days users are most/least active for targeted notifications
SELECT
    DayOfWeek,
    ROUND(AVG(TotalSteps), 0) AS AvgSteps,
    ROUND(AVG(Calories), 0) AS AvgCalories,
    ROUND(AVG(VeryActiveMinutes), 2) AS AvgIntenseActivity
FROM combined_data
GROUP BY DayOfWeek
ORDER BY FIELD(DayOfWeek, 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday');


-- 4. User Engagement (Retention Analysis)
-- Identifies "Power Users" vs "Churn Risks"
SELECT
    Id,
    COUNT(DISTINCT ActivityDate) AS DaysLogged,
    CASE 
        WHEN COUNT(DISTINCT ActivityDate) >= 25 THEN 'High Engagement'
        WHEN COUNT(DISTINCT ActivityDate) BETWEEN 15 AND 24 THEN 'Moderate Engagement'
        ELSE 'Low Engagement'
    END AS UserType
FROM combined_data
GROUP BY Id
ORDER BY DaysLogged DESC;