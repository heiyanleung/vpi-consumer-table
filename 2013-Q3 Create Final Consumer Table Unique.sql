----------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------
-- TESTING TESTING TESTING TESTING TESTING TESTING TESTING TESTING TESTING 
SELECT COUNT(*) FROM (
SELECT DISTINCT
          ct.source_str AS unique_id
          --t.insured_code
          --t.*
          --ct.policyid
      FROM
          ALEUNG.CONS_2013Q1_CONSUMER_TYPE_PIDU ct JOIN ALEUNG.CONS_2013Q1_INFORCE_FINAL t ON (ct.policyid = t.policyid)
          LEFT JOIN ALEUNG.CONS_2013Q1_CSAT csat ON (t.policyid = csat.policyid)
      WHERE
          csat.nps IS NOT NULL
      ORDER BY t.insured_code
) -- 372,737 unique person mapped (98.47%), 373,435 insured codes, 485,002 policy numbers/id's (no=id since only inforce term), 4,002 CSAT records mapped
----------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------
-- APPENDING EXPERIAN INFORMATION TO OUR VPI IN-FORCE POLICY INFORMATION, 
-- THIS TABLE IS "BY POLICY ID", meaning each unique person may have more than one line
CREATE TABLE CONS_2013Q1_AGGREGATE_PIDU
AS
-- SELECT COUNT(*) FROM (
SELECT DISTINCT
    ct.source_str AS unique_id,
    ct.zip,
    ct.needstate,
    ct.typology,
    ct.email_r,
    ct.chnl_dom,
    ct.ad_web,
    ct.ad_mag,
    ct.ad_news,
    ct.ad_rad,
    ct.ad_tv,
    ct.dob,
    substr(ct.age,2,2) age,
    ct.gender,
    ct.hhi,
    ct.marital,
    ct.occupation,
    ct.education,
    ct.political,
    ct.statecode,
    ct.countycode,
    ct.censustract,
    ct.censusblock,
    ct.blockid,
    ct.mcdccd,
    ct.cbsa,
    ct.ethnicinsight,
    ct.ethnicitydtl,
    ct.language,
    ct.religion,
    ct.ethniccode,
    ct.etechgroup,
    ct.coo,
    ct.totalemt,
    ct.cmlevel,
    ct.smlevel,
    csat.nps,
    csat.likelihoodtokeep,
    t.*
FROM
    ALEUNG.CONS_2013Q1_CONSUMER_TYPE_PIDU ct JOIN ALEUNG.CONS_2013Q1_INFORCE_FINAL t ON (ct.policyid = t.policyid)
    LEFT JOIN ALEUNG.CONS_2013Q1_CSAT csat ON (t.policyid = csat.policyid)
ORDER BY t.insured_code
)  -- 372,737 unique person mapped (382,765, 97%), 485,002 records (policy ID's) showing




----------------------------------------------------------------------------------------------------------------------------------------------------
-- Can think about using Excel PowerPivot to work on the below calculations
CREATE TABLE CONS_2013Q1_AGGREGATE_TEMPCALC
AS
-- SELECT COUNT(*) FROM (
SELECT DISTINCT
       cons.unique_id,
       MAX(insured_code) max_insured_code,
       MAX(policy_renew_No) max_renew,
       SUM(cons.medicalclaimcount) med_claim#,
       SUM(welcareclaimcount) wel_claim#,
       SUM(medicalclaimamount) med_claim$,
       SUM(medicalpaidamount) med_paid$,
       SUM(medicaleligibleamount) med_elig$,
       SUM(welcareclaimamount) wel_claim$,
       SUM(welcarepaidamount) wel_paid$,
       SUM(welcareeligibleamount) wel_elig$,
       SUM(premium) premium,
       SUM(fees) fees
FROM 
      ALEUNG.CONS_2013Q1_AGGREGATE_PID cons
GROUP BY
      cons.unique_id
ORDER BY max_insured_code
)  382,739 unique PH (99.9%) shown as of 5/14/2013

















-- Temp table of all calculations by unique_id
CREATE TABLE CONS_2013Q1_AGGREGATE_TEMPCALC
AS
-- SELECT COUNT(*) FROM (
SELECT DISTINCT
       cons.unique_id,
       MAX(insured_code) max_insured_code,
       MAX(policy_renew_No) max_renew,
       SUM(cons.medicalclaimcount) med_claim#,
       SUM(welcareclaimcount) wel_claim#,
       SUM(medicalclaimamount) med_claim$,
       SUM(medicalpaidamount) med_paid$,
       SUM(medicaleligibleamount) med_elig$,
       SUM(welcareclaimamount) wel_claim$,
       SUM(welcarepaidamount) wel_paid$,
       SUM(welcareeligibleamount) wel_elig$,
       SUM(premium) premium,
       SUM(fees) fees
FROM 
      (SELECT DISTINCT
          ct.source_str AS unique_id,
          t.*
      FROM
          ALEUNG.CONS_2013Q1_CONSUMER_TYPE ct LEFT JOIN CONS_2013Q1_INFORCE_FINAL t
                 ON (ct.source_str = UPPER(REPLACE(t.insured_fname, ' ', '') || REPLACE(t.insured_lname, ' ', '') || REPLACE(SUBSTR(t.insured_address1,1,8), ' ', '')))
      ORDER BY t.insured_code) cons
GROUP BY
      cons.unique_id
ORDER BY max_insured_code
--)  382,739 unique PH (99.9%) shown as of 5/14/2013
----------------------------------------------------------------------------------------------------------------------------------------------------
-- JOIN THE TABLES BY PH
SELECT COUNT(*) FROM
(
SELECT DISTINCT
          ct.full_name,
          ct.lastname,
          ct.firstname,
          ct.addr,
          ct.city,
          ct.statealpha state,
          ct.zip,
          ct.needstate,
          ct.typology,
          ct.dob,
          substr(ct.age,2,2) age,
          calc.*,
          cast(calc.med_paid$/nullif(calc.med_claim#,0) AS DECIMAL(10,2)) ppmc,
          cast(calc.wel_paid$/nullif(calc.wel_claim#,0) AS DECIMAL(10,2)) ppwc
FROM
          ALEUNG.CONS_2013Q1_TEMPCALC calc JOIN ALEUNG.CONS_2013Q1_CONSUMER_TYPE ct ON (calc.unique_id = ct.source_str)
)
