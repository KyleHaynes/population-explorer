
/*
This program calculates total benefits per individual for each year ending March.

'First tier' is income tested benefits.  'Second tier' is non-income tested.  'Third tier' is emergency loans or something - they
only have a single day, whereas First and Second tier are spells that apply over time and have a daily rate.

Strategy is:
- create a single table with the start and end dates, number of days and daily amount of Tier 1, Tier 2 and Tier 3 benefits
  for everyone in the spine, and save this as an intermediate table as we'll want it for monthly and quarterly versions too maybe.
- create another table of the first day and last day of each year ending march period
- combine the two and aggregate up the results by snz_uid and YE Mar and save 

Peter Ellis 27 September 2017
17 November modified so it creates a monthly version having sorted out the overlapping spells
*/


IF OBJECT_ID('IDI_Sandpit.intermediate.spells_benefits') IS NOT NULL 
	DROP TABLE IDI_Sandpit.intermediate.spells_benefits;
IF OBJECT_ID('IDI_Sandpit.intermediate.benefits_ye_dec') IS NOT NULL 
	DROP TABLE IDI_Sandpit.intermediate.benefits_ye_dec
IF OBJECT_ID('tempdb..#period_boundaries') IS NOT NULL
	DROP TABLE #period_boundaries;
GO  


--------------------combine the three tiers of benefits-----------------------------
SELECT 
	a.snz_uid,
	msd_fte_end_date       AS end_date, 
	msd_fte_start_date     AS start_date, 
	msd_fte_period_nbr     AS days, 
	msd_fte_daily_nett_amt AS net_amt,
	1					   AS tier
INTO IDI_Sandpit.intermediate.spells_benefits
FROM IDI_Clean.msd_clean.msd_first_tier_expenditure AS a
LEFT JOIN IDI_Clean.data.personal_detail b
ON a.snz_uid = b.snz_uid
WHERE snz_spine_ind = 1

INSERT IDI_Sandpit.intermediate.spells_benefits (snz_uid, end_date, start_date, days, net_amt, tier)
SELECT 
	a.snz_uid,
	msd_ste_end_date       AS end_date, 
	msd_ste_start_date     AS start_date, 
	msd_ste_period_nbr     AS days, 
	msd_ste_daily_nett_amt AS net_amt,
	2					   AS tier
FROM IDI_Clean.msd_clean.msd_second_tier_expenditure AS a
LEFT JOIN IDI_Clean.data.personal_detail b
ON a.snz_uid = b.snz_uid
WHERE snz_spine_ind = 1

INSERT IDI_Sandpit.intermediate.spells_benefits (snz_uid, end_date, start_date, days, net_amt, tier)
SELECT 
	a.snz_uid,
	msd_tte_decision_date       AS end_date, 
	msd_tte_decision_date       AS start_date, 
	1                           AS days, -- one day due to third tier being one-off payments
	msd_tte_pmt_amt             AS net_amt,
	3							AS tier
FROM IDI_Clean.msd_clean.msd_third_tier_expenditure AS a
LEFT JOIN IDI_Clean.data.personal_detail AS b
ON a.snz_uid = b.snz_uid
WHERE snz_spine_ind = 1

CREATE CLUSTERED INDEX idx1 ON IDI_Sandpit.intermediate.spells_benefits (snz_uid, start_date, end_date);
-- There's no natural primary key for this grain because it's not uncommon for people to stop and start on more
-- than one benefit at once.  


---------------------split out spells that overlap quarters----------------------
-- Create reference temp table #yearmonths with years and quarters by start date and end date

IF OBJECT_ID('tempdb..#yearqtrs') IS NOT NULL
    DROP TABLE #yearqtrs

SELECT  DISTINCT
	year_nbr,
	qtr_nbr,
	qtr_start_date,
	qtr_end_date
INTO #yearqtrs
FROM IDI_Sandpit.pop_exp_dev.dim_date
WHERE year_nbr >= (SELECT YEAR(MIN(start_date)) FROM IDI_Sandpit.intermediate.spells_benefits) AND
		year_nbr <= (SELECT YEAR(MAX(end_date)) FROM IDI_Sandpit.intermediate.spells_benefits) AND
		date_dt <= GETDATE() -- otherwise some people are assumed to be in benefits forever...




-- Use yearqtr reference table to aggregate by yearqtr
-- This takes a long time to run, and it creates a row for each person - quarter - tier - net amount combination

IF OBJECT_ID('IDI_Sandpit.intermediate.days_on_benefits') IS NOT NULL
       DROP TABLE IDI_Sandpit.intermediate.days_on_benefits
GO

SELECT 
	snz_uid,
	qtr_end_date,
    SUM(ben_days) AS days_in_benefits,
	tier,
	net_amt
INTO  IDI_Sandpit.intermediate.days_on_benefits
FROM (
       SELECT 
		a.snz_uid,
		yq.qtr_end_date,
		tier,
		net_amt,
        CASE	WHEN start_date >= qtr_start_date AND end_date <= qtr_end_date THEN DATEDIFF(DAY, start_date, end_date) + 1  -- spell all within one quarter
				WHEN start_date >= qtr_start_date AND end_date  > qtr_end_date THEN DATEDIFF(DAY, start_date, qtr_end_date) + 1 -- starting quarter of spell that spans more than one quarter
				WHEN start_date < qtr_start_date AND end_date  <= qtr_end_date THEN DATEDIFF(DAY, qtr_start_date, end_date) + 1 -- ending quarter of spell that spans more than one quarter
				WHEN start_date < qtr_start_date AND end_date  > qtr_end_date THEN DATEDIFF(DAY, qtr_start_date, qtr_end_date ) + 1 -- spell spans the entire quarter
			ELSE 0
        END	AS ben_days
        FROM IDI_Sandpit.intermediate.spells_benefits AS a 
		INNER JOIN #yearqtrs AS yq
              ON	(start_date >= qtr_start_date  AND start_date <= qtr_end_date) -- start quarter of spell
				 OR (end_date >= qtr_start_date  AND end_date <= qtr_end_date) -- end quarter of spell
				 OR (start_date < qtr_start_date  AND end_date > qtr_end_date) -- all the quarters in middle of spell
       ) AS t1
GROUP BY snz_uid, qtr_end_date, tier, net_amt
GO

-- There's no natural primary key here because it's possible to be on two types of the same tier benefit at once.
-- So we just make an index

CREATE CLUSTERED INDEX ind_ben_days ON IDI_Sandpit.intermediate.days_on_benefits(snz_uid, qtr_end_date, tier);


EXECUTE IDI_Sandpit.lib.add_cs_ind 'intermediate', 'days_on_benefits';