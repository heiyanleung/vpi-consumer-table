-- Inforce Table. Drop it if exist. Validate the total Inforce with BI Report VP0001.
-- Step 1
Create table CONS_2013Q1_INFORCE
AS
--SELECT count(*) FROM(
SELECT
    ph.policyid,
    ph.policy_no,
    ph.policy_renew_no,
    ph.insured_code
FROM
    dwadmin.dw_policy_header ph JOIN dwadmin.dw_data_inforce i ON (ph.policyid = i.policyid)
WHERE
    i.reportperiod = to_date('02/28/2013','MM/DD/YYYY')
--)496,449 records as of 05/02/2013
; 
------------------------------------------------------------------------------------------------------------------------------------
-- Add more dimensions            
CREATE TABLE CONS_2013Q1_INFORCE_DTL
AS
--SELECT COUNT(*) FROM (
(
SELECT DISTINCT
    i.policyid,
    i.policy_no,
    i.policy_renew_no,
    ph.insured_code,
    pp.pp_petname,
    pp.pp_pet_sex,
    pp.pp_date_of_birth,
    em.insured_fname,
    em.insured_lname,
    em.insured_address1,
    em.insured_address2,
    em.insured_city,
    em.insured_state,
    em.insured_zipcode,
    em.insured_hometel,
    em.insured_bustel,
    em.insured_email,
    em.policy_inforce_cnt,
    em.portal_user_flag,
    ph.effective_date,
    br.breed_code,
    br.breed_desc,
    br.speciescode,
    wp.baseproduct,
    case when WP.VRCC = 99 then 'VRCC'
         when wp.VRCC = 144 then 'Core'
         when wp.VRCC = 264 then 'Premier' else '' end WellCare_Type,
    case wp.CANCER when 0 then 'N' else 'Y' end CancerYN,
    wp.vrcc,
    wp.cancer,
    s.source_desc,
    o.origin_type,
    o.origin_code,
    pl.paymentplandesc,
    pr.provider_name,
    ph.group_id,
    g.group_code
FROM
    ALEUNG.CONS_2013Q1_INFORCE i JOIN renvpi.policy_pets@vpibsa pp ON (i.policy_no = pp.pp_policy_no) AND (i.policy_renew_no = pp.pp_policy_renew_no)
                                 JOIN dwadmin.dw_policy_header ph ON (ph.policyid = i.policyid)
                                 JOIN dwdaily.dw_dim_insured em ON (ph.insured_code = em.insured_code)
                                 LEFT JOIN dwadmin.dw_dim_group g ON (ph.group_id = g.group_id)
                                 JOIN dwadmin.dw_dim_breed br ON (ph.breed_id = br.breed_id)
                                 JOIN dwadmin.dw_wp wp ON (ph.policyid = wp.policyid)
                                 JOIN dwadmin.dw_dim_source s ON (ph.source_id = s.source_id)
                                 JOIN dwadmin.dw_dim_origin o ON (ph.origin_id = o.origin_id)
                                 JOIN dwadmin.dw_dim_paymentplan PL ON (ph.paymentplan_id = pl.paymentplan_id)
                                 LEFT JOIN dwadmin.dw_dim_provider pr ON (ph.provider_id = pr.provider_id)
)
--)  496,449 records as of 05/02/2013
;
------------------------------------------------------------------------------------------------------------------------------------
--  Create temp table for Wellcare Claims (these are amounts across all terms of a given policy)
CREATE TABLE CONS_2013Q1_WELLCLAIMS_DW
AS
--SELECT COUNT(*) FROM(
SELECT
    a.policy_no,
    COUNT(a.claim_no) wccount,
    SUM(a.claimedamount) Claimamount,
    SUM(a.paidamount) paidamount,
    SUM(a.eligibleamount) eligibleamount
FROM
    (
    SELECT
        ph.policy_no,
        ch.claim_no,
        SUM(cdt.claimedamount) claimedamount,
        SUM(cdt.paidamount) paidamount,
        SUM(cdt.eligibleamount) eligibleamount    
    FROM
        dwadmin.dw_policy_header ph JOIN dwadmin.dw_claim_header ch ON (ph.policyid = ch.policyid)
                            JOIN dwadmin.dw_claim_revision cr ON (ch.claim_id = cr.claim_id)
                            JOIN dwadmin.dw_claim_diagnosis cd ON (cr.claim_id = cd.claim_id) AND (cr.claim_revision_no = cd.claim_revision_no)
                            JOIN dwadmin.dw_claim_details cdt ON (cd.claim_diagnosis_id = cdt.claim_diagnosis_id)
                            JOIN dwadmin.dw_dim_coverage c ON (cd.claim_coverage_id = c.coverage_id)
    WHERE
        c.coverage_product_type = 'Wellcare' AND
        cr.claim_revision_status  <> 'Reopened'  -- Need to count all Claims Filed on top of Claim Complete
    GROUP BY
        ph.policy_no,
        ch.claim_no
    ORDER BY
        ph.policy_no 
    ) a
GROUP BY
    a.policy_no 
--    )
;
------------------------------------------------------------------------------------------------------------------------------------
--  Create temp table for Medical Claims (these are amounts across all terms of a given policy)
CREATE TABLE CONS_2013Q1_MEDCLAIMS_DW
AS
SELECT
    a.policy_no,
    COUNT(*) medcount,
    SUM(a.claimedamount) Claimamount,
    SUM(a.paidamount) paidamount,
    SUM(a.eligibleamount) eligibleamount
FROM
    (
    SELECT
        ph.policy_no,
        ch.claim_no,
        SUM(cdt.claimedamount) claimedamount,
        SUM(cdt.paidamount) paidamount,
        SUM(cdt.eligibleamount) eligibleamount 
    FROM
        dwadmin.dw_policy_header ph JOIN dwadmin.dw_claim_header ch ON (ph.policyid = ch.policyid)
                         JOIN dwadmin.dw_claim_revision cr ON (ch.claim_id = cr.claim_id)
                         JOIN dwadmin.dw_claim_diagnosis cd ON (cr.claim_id = cd.claim_id) AND (cr.claim_revision_no = cd.claim_revision_no)
                         JOIN dwadmin.dw_dim_coverage c ON (cd.claim_coverage_id = c.coverage_id)
                         JOIN dwadmin.dw_claim_details cdt ON (cd.claim_diagnosis_id = cdt.claim_diagnosis_id)
    WHERE
         c.coverage_product_type <> 'Wellcare' AND -- Includes Base and Cancer
         cr.claim_revision_status  <> 'Reopened' -- Need to count all Claims Filed on top of Claim Complete
    GROUP BY
        ph.policy_no,
        ch.claim_no
    ORDER BY
        ph.policy_no 
    ) a
GROUP BY
    a.policy_no
;
------------------------------------------------------------------------------------------------------------------------------------
--  Create temp table for Premiums (these are amounts across all terms of a given policy)
CREATE TABLE CONS_2013Q1_PREMIUM_FEES_DW
AS
SELECT
    pre.policy_no,
    COUNT(*) earncount,
    SUM(pre.earnedpremium) earned_pre,
    SUM(fee.earnedfees) earned_fee
FROM
    DWADMIN.DW_EPREMIUM_UEPREMIUM_POLICY pre LEFT JOIN DWADMIN.DW_EFEES_UEFEES_POLICY fee ON (pre.policy_no = fee.policy_no) 
                                                                                          AND (pre.policy_renew_no = fee.policy_renew_no)
                                                                                          AND (pre.reportperiod = fee.reportperiod)
GROUP BY
    pre.policy_no
ORDER BY
    pre.policy_no
;
------------------------------------------------------------------------------------------------------------------------------------
--INFORCE POLICIES WITH MEDICAL AND WELLNESS CLAIMS and GROUP NAME
CREATE TABLE CONS_2013Q1_INFORCE_AGGREGATE
AS
--SELECT count(*) FROM (
SELECT a.*,
       g.group_name,
       min(a.policy_renew_no) over (partition by a.insured_code) min_term,
       max(a.policy_renew_no) over (partition by a.insured_code) max_term,
       sum(decode(a.speciescode,'C',1,0)) over (partition by a.insured_code) Dogs,
       sum(decode(a.speciescode,'F',1,0)) over (partition by a.insured_code) Cats,
       sum(decode(a.speciescode,'A',1,0)) over (partition by a.insured_code) Avian,
       sum(case when a.speciescode in ('E','R') then 1 else 0 end) over (partition by a.insured_code) ExoticOthers
FROM
      (
      SELECT t.*,
             case when mdw.medcount is null then 0 else mdw.medcount end MedicalClaimCount,
             case when mvw.wccount is null then 0 else mvw.wccount end WelcareClaimCount,
             case when mdw.claimamount is null then 0 else mdw.claimamount end medicalclaimamount,
             case when mdw.paidamount is null then 0 else mdw.paidamount end medicalpaidamount,
             case when mdw.eligibleamount is null then 0 else mdw.eligibleamount end medicaleligibleamount,
             case when mvw.claimamount is null then 0  else mvw.claimamount end welcareclaimamount,
             case when mvw.paidamount is null then 0 else mvw.paidamount end welcarepaidamount,
             case when mvw.eligibleamount is null then 0 else mvw.eligibleamount end welcareeligibleamount,
             earn.earned_pre premium,
             earn.earned_fee fees,
             p.Total_pets
      FROM 
             ALEUNG.CONS_2013Q1_INFORCE_DTL t LEFT JOIN ALEUNG.CONS_2013Q1_MEDCLAIMS_DW mdw ON (t.policy_no = mdw.policy_no)
                             LEFT JOIN ALEUNG.CONS_2013Q1_WELLCLAIMS_DW mvw ON (t.policy_no = mvw.policy_no)
                             LEFT JOIN ALEUNG.CONS_2013Q1_PREMIUM_FEES_DW earn ON (t.policy_no = earn.policy_no)
                             LEFT JOIN (SELECT q.insured_code, COUNT(q.policy_no) Total_Pets FROM ALEUNG.CONS_2013Q1_INFORCE_DTL q GROUP BY q.insured_code) p ON (t.Insured_Code = p.Insured_Code)                          
      ORDER BY 
            t.policy_no,
            t.policy_renew_no 
      ) a LEFT JOIN dwadmin.dw_dim_group g ON (a.group_code = g.group_code)
ORDER BY a.Insured_Code
--) 496,449 records as of 5/14/2013
;
------------------------------------------------------------------------------------------------------------------------------------
-- To Add Policies referred by insured
CREATE TABLE CONS_2013Q1_INFORCE_FINAL AS
-- SELECT COUNT(*) FROM (
SELECT 
       a.*, 
       referred.Policy_referred_Count
FROM 
       ALEUNG.CONS_2013Q1_INFORCE_AGGREGATE a LEFT JOIN 
       (
       SELECT 
        vi.vi_insured, 
        count(distinct vi.vi_ref_policy_no) Policy_Referred_count
        FROM 
        renvpi.vouchers_issued@vpibsa vi
                     JOIN dwadmin.dw_policy_header ph ON (vi.vi_ref_policy_no = ph.policy_no) 
                                                   AND (vi.vi_ref_policy_renew_no = ph.policy_renew_no)
                                                   AND (vi.vi_insured <> ph.insured_code)
                     WHERE vi.vi_redeemed_yn = 'Y'
                     GROUP BY vi.vi_insured
                     ) referred  -- Find Referral Policy Count
        ON (a.insured_code = referred.vi_insured)
-- ) 496,449 records as of 5/14/2013
; 
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------


-- Create table File 1A -- Aggregate File 1 by Policyholder (Insured Code is being used here: note that there might be multiple insured code per unique person)
create table NPS_F1A as
--SELECT count(*) FROM (
SELECT a.*
FROM 
       aleung.NPS_F1 a JOIN 
       (SELECT i.insured_code, 
               min(i.policy_no) min_policy_no 
        FROM aleung.AH_INFORCE_NPS i 
        GROUP BY i.insured_code) b ON (a.insured_code = b.insured_code) AND (a.policy_no = b.min_policy_no)
--) 382,546 records as of 5/14/2013
; 
------------------------------------------------------------------------------------------------------------------------------------

--Combine all Scrub Excel files into a CSV file then use text importer to import data into NPS_SCRUBBER (Insured Code and the Source file)
-- Import All Files A1, A2, B1, B2, C1, C2, D1, D2
-- Execute the following query to validate the import
SELECT source, count(*) FROM NPS_SCRUBBER GROUP BY SOURCE ORDER BY SOURCE;
SELECT * FROM NPS_SCRUBBER; -- Count = 15,080 
SELECT COUNT(*) FROM NPS_SCRUBBER;
SELECT COUNT(*) FROM NPS_SCRUBBER_POLICY;
SELECT COUNT(*) FROM NPS_SCRUBBER_DNC;

-- Import 2012-EOB survey (G1) using Text importer to NPS_SCRUBER_POLICY
-- G1 need to get Insured Code by joining Policy_no to dw_policy_header
;

INSERT INTO NPS_SCRUBBER 
(SELECT DISTINCT ph.insured_code, p.source
FROM nps_scrubber_policy p
JOIN dwadmin.dw_policy_header ph
     ON trim(p.policy_no) = ph.policy_no); -- Count=1598

-- Import Do Not Contact List (H) using Text importer to NPS_SCRUBE_DNC     
-- H need to get Insured Code by joining email address to dw_policy_header
INSERT INTO NPS_SCRUBBER
(SELECT /*DISTINCT */i.insured_code, p.source
FROM NPS_SCRUBBER_DNC p
JOIN dwadmin.dw_dim_insured i
     ON lower(p.email) = lower(i.insured_email)) ; -- Count=1100 (Not all Email are policyholder)

------------------------------------------------------------------------------------------------------------------------------------
-- Create table for File 2
create table NPS_F2
AS (
select a.*
from NPS_F1A a
     left join (select distinct s.insured_code from NPS_SCRUBBER s) n 
               on (a.insured_code = trim(n.insured_code))
     left join (select distinct upper(bad_email) bad_email from bad_email) b 
               on (upper(a.insured_email) = upper(b.bad_email))
          join dwdaily.dw_policy_pet p 
               on (a.policy_no = p.policy_no)
          join dwdaily.dw_dim_policy_status ps 
               on (p.policy_status_dwid = ps.policy_status_dwid)
     LEFT JOIN (select f.insured_code
                FROM NPS_F1A f
                JOIN dwdaily.dw_policy_term pt
                     ON (f.policy_no = pt.policy_no AND f.policy_renew_no = pt.policy_renew_no)
                JOIN dwdaily.dw_cancel c
                     ON (pt.policy_term_dwid = c.policy_term_dwid)
                WHERE c.effective_date >= trunc(SYSDATE)) canc  
                ON (a.insured_code = canc.insured_code)                                           
where     
      n.insured_code is null    
      and b.bad_email is null
      and a.origin_code not IN ('GD0082', 'GD0174', 'GP0082', 'GP0083') -- to exclude VPI Employee instead of Group Code (note from Todd) -- Scrub GD0082, GD0174, GP0082, GP0083   
      and ps.policy_status_desc IN ('Inforce', 'Inforce (Undernotice)')  -- Keep Inforce Policy as of yesterday
      AND canc.insured_code IS NULL)  -- Exclude future Cancellation
;
-- COUNT=362,202
;

------------------------------------------------------------------------------------------------------------------------------------
-- Generate F2A Table Policyholder with email address only
create table NPS_F2A as
select f.*
from NPS_F2 f
     JOIN (SELECT MIN(a.policy_no) Policy_No 
           FROM NPS_F2 a GROUP BY lower(a.insured_email)) dp
        ON (f.policy_no = dp.policy_no)
where f.insured_email like '%@%' OR f.insured_email LIKE '%.%'
;
-- COUNT=340,011

------------------------------------------------------------------------------------------------------------------------------------
-- Create Table F3
create table NPS_F3 as
SELECT * FROM
( SELECT b.* 
  FROM NPS_F2A b
  ORDER BY dbms_random.value )
WHERE rownum <= 80000
;
-- Generate File 3
Select * FROM NPS_F3;
Select COUNT(*) FROM NPS_F3;

------------------------------------------------------------------------------------------------------------------------------------
-- File 4
CREATE TABLE NPS_F4 AS
SELECT *
FROM NPS_F2A a
WHERE a.total_pets = 1 
      AND a.policy_renew_no IN (0,1)
      AND (a.baseproduct like 'M%' or a.baseproduct like 'FS%' or a.baseproduct like 'I%' or a.baseproduct like 'NI%' or a.baseproduct like 'WB%') -- 80,601
MINUS
SELECT * FROM NPS_F3;
-- 61,677
;

------------------------------------------------------------------------------------------------------------------------------------
-- File 4A
Create table NPS_F4A as
Select * FROM
    (SELECT * FROM NPS_F4
    ORDER BY dbms_random.value)
WHERE rownum <= 60000
;


------------------------------------------ RANDOM PULL VALIDATION -----------------------------------

-- Validation File 1
-- pet type
SELECT a.SPECIESCODE, TOT_PET_F1,TOT_PET_F2,TOT_PET_F3 FROM
    (select F1.SPECIESCODE, COUNT(*) TOT_PET_F1
    from NPS_F1A F1
    GROUP BY F1.SPECIESCODE) a
JOIN 
    (select F1.SPECIESCODE, COUNT(*) TOT_PET_F2
    from NPS_F2A F1
    GROUP BY F1.SPECIESCODE) b ON a.SPECIESCODE = b.SPECIESCODE
JOIN
    (select F1.SPECIESCODE, COUNT(*) TOT_PET_F3
    from NPS_F3 F1
    GROUP BY F1.SPECIESCODE) c ON b.SPECIESCODE = c.SPECIESCODE
;

/*
select F1.BASEPRODUCT, COUNT(*) TOT_PET
from NPS_F3 F1
GROUP BY F1.BASEPRODUCT*/
;
-- term no
select a.policy_renew_no, Tot_Pet_1, Tot_Pet_2, Tot_Pet_3 from
      (select f1.policy_renew_no, count(*) Tot_Pet_1
      from NPS_F1A F1
      where f1.policy_renew_no < 18
      GROUP BY f1.policy_renew_no
      union
      select '18' policy_renew_no, count(*) Tot_Pet_1
      from NPS_F1A F1a
      where f1a.policy_renew_no >= 18) a
 left join     
      (select f2.policy_renew_no, count(*) Tot_Pet_2
      from NPS_F2A F2
      where f2.policy_renew_no < 18
      GROUP BY f2.policy_renew_no
      union
      select '18' policy_renew_no, count(*) Tot_Pet_2
      from NPS_F2A F2a
      where f2a.policy_renew_no >= 18) b on a.policy_renew_no = b.policy_renew_no
 left join    
      (select f3.policy_renew_no, count(*) Tot_Pet_3
      from NPS_F3 F3
      where f3.policy_renew_no < 18
      GROUP BY f3.policy_renew_no
      union
      select '18' policy_renew_no, count(*) Tot_Pet_3
      from NPS_F3 F3a
      where f3a.policy_renew_no >= 18) c on b.policy_renew_no = c.policy_renew_no
order by to_number(policy_renew_no)

;
-- Multipet Insured Pet Housholds
select case when f1.total_pets between 1 and 6 then f1.total_pets else 7 end Multipet, count(distinct f1.insured_code) tot_PH
from NPS_F3 F1 -- CHANGE BETWEEN NPS_F1A, NPS_F2, NPS_F3
group by case when f1.total_pets between 1 and 6 then f1.total_pets else 7 end

;
-- Pet Type - by Multi-pet insured code (this count should be less than Pet Type data above)

Select multi_pet, count(*) PH
from (
    select case when f1.exoticothers = 0 and f1.cats >= 1 and f1.exoticothers = 0 and f1.dogs = 0 and f1.avian = 0 then 'A_AllFeline'
                when f1.exoticothers = 0 and f1.cats = 0 and f1.exoticothers = 0 and f1.dogs >= 1 and f1.avian = 0 then 'B_AllCanine'
                when f1.cats = 0 and f1.dogs = 0 and (f1.exoticothers >= 1 or f1.exoticothers >= 1 or f1.avian >= 1) then 'C_AllAvianExotic'
                when f1.exoticothers = 0 and f1.cats >= 1 and f1.exoticothers = 0 and f1.dogs >= 1 and f1.avian = 0 then 'D_CanineFelineMix'
                when f1.dogs >= 1 and f1.cats = 0 and (f1.exoticothers >= 1 or f1.exoticothers >= 1 or f1.avian >= 1) then 'E_CanineOthersMix'
                when f1.cats >= 1 and f1.dogs = 0 and (f1.exoticothers >= 1 or f1.exoticothers >= 1 or f1.avian >= 1) then 'F_FelineOthersMix'
                when f1.dogs >= 1 and f1.cats >= 1 and (f1.exoticothers >= 1 or f1.exoticothers >= 1 or f1.avian >= 1) then 'G_CanineFelineorOthersMix'
                else 'Unknown'  
                end multi_pet
    -- select count(*)            
    from NPS_F3 F1 -- CHANGE BETWEEN NPS_F1A AND NPS_F2A AND NPS_F3
    where f1.total_pets > 1)
group by multi_pet
order by multi_pet

;
-- Pet Type - by Multi-pet insured code and Minimum term of all pets insured (This count should sum to tie with Pet Type- by Multi-pet insured code above)
Select multi_pet, term_group, count(*) PH
from (
    select case when f1.exoticothers = 0 and f1.cats >= 1 and f1.exoticothers = 0 and f1.dogs = 0 and f1.avian = 0 then 'A_AllFeline'
                when f1.exoticothers = 0 and f1.cats = 0 and f1.exoticothers = 0 and f1.dogs >= 1 and f1.avian = 0 then 'B_AllCanine'
                when f1.cats = 0 and f1.dogs = 0 and (f1.exoticothers >= 1 or f1.exoticothers >= 1 or f1.avian >= 1) then 'C_AllAvianExotic'
                when f1.exoticothers = 0 and f1.cats >= 1 and f1.exoticothers = 0 and f1.dogs >= 1 and f1.avian = 0 then 'D_CanineFelineMix'
                when f1.dogs >= 1 and f1.cats = 0 and (f1.exoticothers >= 1 or f1.exoticothers >= 1 or f1.avian >= 1) then 'E_CanineOthersMix'
                when f1.cats >= 1 and f1.dogs = 0 and (f1.exoticothers >= 1 or f1.exoticothers >= 1 or f1.avian >= 1) then 'F_FelineOthersMix'
                when f1.dogs >= 1 and f1.cats >= 1 and (f1.exoticothers >= 1 or f1.exoticothers >= 1 or f1.avian >= 1) then 'G_CanineFelineorOthersMix'
                else 'Unknown'  
                end multi_pet
            ,case when f1.min_term = 0 then '0'
                  when f1.min_term between 1 and 3 then '1 to 3'
                  when f1.min_term between 4 and 5 then '4 to 5'
                  when f1.min_term > 5 then '5 Higher'
             end term_group
    from NPS_F1a F1 -- CHANGE BETWEEN NPS_F1A AND NPS_F2A AND NPS_F3
    where f1.total_pets > 1)
group by multi_pet, term_group
order by multi_pet, term_group
 
;
-- Pet Type - by Multi-pet insured code and Maximum term of all pets insured (This count should sum to tie with Pet Type- by Multi-pet insured code and Minimum term of all Pets above)

Select multi_pet, term_group, count(*) PH
from (
    select case when f1.exoticothers = 0 and f1.cats >= 1 and f1.exoticothers = 0 and f1.dogs = 0 and f1.avian = 0 then 'A_AllFeline'
                when f1.exoticothers = 0 and f1.cats = 0 and f1.exoticothers = 0 and f1.dogs >= 1 and f1.avian = 0 then 'B_AllCanine'
                when f1.cats = 0 and f1.dogs = 0 and (f1.exoticothers >= 1 or f1.exoticothers >= 1 or f1.avian >= 1) then 'C_AllAvianExotic'
                when f1.exoticothers = 0 and f1.cats >= 1 and f1.exoticothers = 0 and f1.dogs >= 1 and f1.avian = 0 then 'D_CanineFelineMix'
                when f1.dogs >= 1 and f1.cats = 0 and (f1.exoticothers >= 1 or f1.exoticothers >= 1 or f1.avian >= 1) then 'E_CanineOthersMix'
                when f1.cats >= 1 and f1.dogs = 0 and (f1.exoticothers >= 1 or f1.exoticothers >= 1 or f1.avian >= 1) then 'F_FelineOthersMix'
                when f1.dogs >= 1 and f1.cats >= 1 and (f1.exoticothers >= 1 or f1.exoticothers >= 1 or f1.avian >= 1) then 'G_CanineFelineorOthersMix'
                else 'Unknown'  
                end multi_pet
            ,case when f1.max_term = 0 then '0'
                  when f1.max_term between 1 and 3 then '1 to 3'
                  when f1.max_term between 4 and 5 then '4 to 5'
                  when f1.max_term > 5 then '5 Higher'
             end term_group
    from NPS_F3 F1 -- CHANGE BETWEEN NPS_F1A AND NPS_F2A AND NPS_F3
    where f1.total_pets > 1)
group by multi_pet, term_group
order by multi_pet, term_group
;

-- group by product type
select case when F1.BASEPRODUCT like 'I250%' then 'I250 (Reg/I250G)' else f1.baseproduct end BaseProduct , COUNT(*) TOT_PET
from NPS_F3 F1 -- CHANGE BETWEEN NPS_F1A AND NPS_F2 AND NPS_F3
GROUP BY case when F1.BASEPRODUCT like 'I250%' then 'I250 (Reg/I250G)' else f1.baseproduct end
order by case when F1.BASEPRODUCT like 'I250%' then 'I250 (Reg/I250G)' else f1.baseproduct end
;

-- Group by State
select f.insured_state, count(*)
from NPS_F3 f -- CHANGE BETWEEN NPS_F1A, NPS_F2, NPS_F3
group by f.insured_state
order by f.insured_state
;

select * from
(select b.insured_state, count(*) from (
select *
from NPS_F3 f
     join dwadmin.dw_policy_header ph on f.policyid = ph.policyid
     join dwadmin.dw_dim_paymentplan pp on ph.paymentplan_id = pp.paymentplan_id
     join dwadmin.dw_dim_payment_type pt on pp.paymentplantypeid = pt.paymentplantype_id
WHERE pt.paymentplantype = 'PIF'
group by f.insured_state
order by count(*) desc) b)
where rownum <=10

;

-- group by Medical claim submitted amount
select b.submitted_group, count(distinct b.policy_no) Policy_count
from (
      select case when a.medicalclaimamount >= 0 and a.medicalclaimamount <= 100 then 'a0 to 100'
                  when a.medicalclaimamount > 100 and a.medicalclaimamount <= 200 then 'b101 to 200'
                  when a.medicalclaimamount > 200 and a.medicalclaimamount <= 300 then 'c201 to 300'
                  when a.medicalclaimamount > 300 and a.medicalclaimamount <= 400 then 'd301 to 400'
                  when a.medicalclaimamount > 400 and a.medicalclaimamount <= 500 then 'e401 to 500'
                  when a.medicalclaimamount > 500 and a.medicalclaimamount <= 600 then 'f501 to 600'
                  when a.medicalclaimamount > 600 and a.medicalclaimamount <= 700 then 'g601 to 700'
                  when a.medicalclaimamount > 700 and a.medicalclaimamount <= 800 then 'h701 to 800'
                  when a.medicalclaimamount > 800 and a.medicalclaimamount <= 900 then 'i801 to 900'
                  when a.medicalclaimamount > 900 and a.medicalclaimamount <= 1000 then 'j901 to 1000'
                  when a.medicalclaimamount > 1000 and a.medicalclaimamount <= 1200 then 'k1001 to 1200'
                  when a.medicalclaimamount > 1200 and a.medicalclaimamount <= 1400 then 'l1201 to 1400'
                  when a.medicalclaimamount > 1400 and a.medicalclaimamount <= 1600 then 'm1401 to 1600'
                  when a.medicalclaimamount > 1600 and a.medicalclaimamount <= 1800 then 'n1601 to 1800'
                  when a.medicalclaimamount > 1800 and a.medicalclaimamount <= 2000 then 'o1801 to 2000'
                  when a.medicalclaimamount > 2000 and a.medicalclaimamount <= 3000 then 'p2001 to 3000'
                  when a.medicalclaimamount > 3000 and a.medicalclaimamount <= 4000 then 'q3001 to 4000'
                  when a.medicalclaimamount > 4000 and a.medicalclaimamount <= 5000 then 'r4001 to 5000'
                  when a.medicalclaimamount > 5000 then 's5000 Higher'
               end Submitted_Group
               , a.policy_no
      from NPS_F1a a
      where a.medicalclaimcount >= 0
      ) b
group by b.submitted_group
order by b.submitted_group
;
-- group by Medical Eligible amount
select b.Eligible_group, count(distinct b.policy_no) Policy_count
from (
      select case when a.medicaleligibleamount >= 0 and a.medicaleligibleamount <= 100 then 'a0 to 100'
                  when a.medicaleligibleamount > 100 and a.medicaleligibleamount <= 200 then 'b101 to 200'
                  when a.medicaleligibleamount > 200 and a.medicaleligibleamount <= 300 then 'c201 to 300'
                  when a.medicaleligibleamount > 300 and a.medicaleligibleamount <= 400 then 'd301 to 400'
                  when a.medicaleligibleamount > 400 and a.medicaleligibleamount <= 500 then 'e401 to 500'
                  when a.medicaleligibleamount > 500 and a.medicaleligibleamount <= 600 then 'f501 to 600'
                  when a.medicaleligibleamount > 600 and a.medicaleligibleamount <= 700 then 'g601 to 700'
                  when a.medicaleligibleamount > 700 and a.medicaleligibleamount <= 800 then 'h701 to 800'
                  when a.medicaleligibleamount > 800 and a.medicaleligibleamount <= 900 then 'i801 to 900'
                  when a.medicaleligibleamount > 900 and a.medicaleligibleamount <= 1000 then 'j901 to 1000'
                  when a.medicaleligibleamount > 1000 and a.medicaleligibleamount <= 1200 then 'k1001 to 1200'
                  when a.medicaleligibleamount > 1200 and a.medicaleligibleamount <= 1400 then 'l1201 to 1400'
                  when a.medicaleligibleamount > 1400 and a.medicaleligibleamount <= 1600 then 'm1401 to 1600'
                  when a.medicaleligibleamount > 1600 and a.medicaleligibleamount <= 1800 then 'n1601 to 1800'
                  when a.medicaleligibleamount > 1800 and a.medicaleligibleamount <= 2000 then 'o1801 to 2000'
                  when a.medicaleligibleamount > 2000 and a.medicaleligibleamount <= 3000 then 'p2001 to 3000'
                  when a.medicaleligibleamount > 3000 and a.medicaleligibleamount <= 4000 then 'q3001 to 4000'
                  when a.medicaleligibleamount > 4000 and a.medicaleligibleamount <= 5000 then 'r4001 to 5000'
                  when a.medicaleligibleamount > 5000 then 's5000 Higher'
               end Eligible_group
               , a.policy_no
      from NPS_F1a a
      where a.medicalclaimcount >= 0
      ) b
group by b.Eligible_group
order by b.Eligible_group
;

-- group by Medical claim paid amount
select b.reimbursement_grp, count(distinct b.policy_no) Policy_count
from (
      select case when a.medicalpaidamount >= 0 and a.medicalpaidamount <= 100 then 'a0 to 100'
                  when a.medicalpaidamount > 100 and a.medicalpaidamount <= 200 then 'b101 to 200'
                  when a.medicalpaidamount > 200 and a.medicalpaidamount <= 300 then 'c201 to 300'
                  when a.medicalpaidamount > 300 and a.medicalpaidamount <= 400 then 'd301 to 400'
                  when a.medicalpaidamount > 400 and a.medicalpaidamount <= 500 then 'e401 to 500'
                  when a.medicalpaidamount > 500 and a.medicalpaidamount <= 600 then 'f501 to 600'
                  when a.medicalpaidamount > 600 and a.medicalpaidamount <= 700 then 'g601 to 700'
                  when a.medicalpaidamount > 700 and a.medicalpaidamount <= 800 then 'h701 to 800'
                  when a.medicalpaidamount > 800 and a.medicalpaidamount <= 900 then 'i801 to 900'
                  when a.medicalpaidamount > 900 and a.medicalpaidamount <= 1000 then 'j901 to 1000'
                  when a.medicalpaidamount > 1000 and a.medicalpaidamount <= 1200 then 'k1001 to 1200'
                  when a.medicalpaidamount > 1200 and a.medicalpaidamount <= 1400 then 'l1201 to 1400'
                  when a.medicalpaidamount > 1400 and a.medicalpaidamount <= 1600 then 'm1401 to 1600'
                  when a.medicalpaidamount > 1600 and a.medicalpaidamount <= 1800 then 'n1601 to 1800'
                  when a.medicalpaidamount > 1800 and a.medicalpaidamount <= 2000 then 'o1801 to 2000'
                  when a.medicalpaidamount > 2000 and a.medicalpaidamount <= 3000 then 'p2001 to 3000'
                  when a.medicalpaidamount > 3000 and a.medicalpaidamount <= 4000 then 'q3001 to 4000'
                  when a.medicalpaidamount > 4000 and a.medicalpaidamount <= 5000 then 'r4001 to 5000'
                  when a.medicalpaidamount > 5000 then 's5000 Higher'
               end reimbursement_grp
               , a.policy_no
      from NPS_F3 a
      where a.medicalclaimcount >= 0
      ) b
group by b.reimbursement_grp
order by b.reimbursement_grp
;
-- group by Welcare claim submitted amount
select b.well_Submitted_Group, count(distinct b.policy_no) Policy_count
from (
      select case when a.welcareclaimamount >= 0 and a.welcareclaimamount <= 100 then 'a0 to 100'
                  when a.welcareclaimamount > 100 and a.welcareclaimamount <= 200 then 'b101 to 200'
                  when a.welcareclaimamount > 200 and a.welcareclaimamount <= 300 then 'c201 to 300'
                  when a.welcareclaimamount > 300 and a.welcareclaimamount <= 400 then 'd301 to 400'
                  when a.welcareclaimamount > 400 and a.welcareclaimamount <= 500 then 'e401 to 500'
                  when a.welcareclaimamount > 500 and a.welcareclaimamount <= 600 then 'f501 to 600'
                  when a.welcareclaimamount > 600 and a.welcareclaimamount <= 700 then 'g601 to 700'
                  when a.welcareclaimamount > 700 and a.welcareclaimamount <= 800 then 'h701 to 800'
                  when a.welcareclaimamount > 800 and a.welcareclaimamount <= 900 then 'i801 to 900'
                  when a.welcareclaimamount > 900 and a.welcareclaimamount <= 1000 then 'j901 to 1000'
                  when a.welcareclaimamount > 1000 and a.welcareclaimamount <= 1200 then 'k1001 to 1200'
                  when a.welcareclaimamount > 1200 and a.welcareclaimamount <= 1400 then 'l1201 to 1400'
                  when a.welcareclaimamount > 1400 and a.welcareclaimamount <= 1600 then 'm1401 to 1600'
                  when a.welcareclaimamount > 1600 and a.welcareclaimamount <= 1800 then 'n1601 to 1800'
                  when a.welcareclaimamount > 1800 and a.welcareclaimamount <= 2000 then 'o1801 to 2000'
                  when a.welcareclaimamount > 2000 and a.welcareclaimamount <= 3000 then 'p2001 to 3000'
                  when a.welcareclaimamount > 3000 and a.welcareclaimamount <= 4000 then 'q3001 to 4000'
                  when a.welcareclaimamount > 4000 and a.welcareclaimamount <= 5000 then 'r4001 to 5000'
                  when a.welcareclaimamount > 5000 then 's5000 Higher'
               end well_Submitted_Group
               , a.policy_no
      from NPS_F3 a
      where a.welcareclaimcount >= 0
      ) b
group by b.well_Submitted_Group
order by b.well_Submitted_Group
;
-- group by Welcare Eligible amount
select b.Well_Eligible_group, count(distinct b.policy_no) Policy_count
from (
      select case when a.welcareeligibleamount >= 0 and a.welcareeligibleamount <= 100 then 'a0 to 100'
                  when a.welcareeligibleamount > 100 and a.welcareeligibleamount <= 200 then 'b101 to 200'
                  when a.welcareeligibleamount > 200 and a.welcareeligibleamount <= 300 then 'c201 to 300'
                  when a.welcareeligibleamount > 300 and a.welcareeligibleamount <= 400 then 'd301 to 400'
                  when a.welcareeligibleamount > 400 and a.welcareeligibleamount <= 500 then 'e401 to 500'
                  when a.welcareeligibleamount > 500 and a.welcareeligibleamount <= 600 then 'f501 to 600'
                  when a.welcareeligibleamount > 600 and a.welcareeligibleamount <= 700 then 'g601 to 700'
                  when a.welcareeligibleamount > 700 and a.welcareeligibleamount <= 800 then 'h701 to 800'
                  when a.welcareeligibleamount > 800 and a.welcareeligibleamount <= 900 then 'i801 to 900'
                  when a.welcareeligibleamount > 900 and a.welcareeligibleamount <= 1000 then 'j901 to 1000'
                  when a.welcareeligibleamount > 1000 and a.welcareeligibleamount <= 1200 then 'k1001 to 1200'
                  when a.welcareeligibleamount > 1200 and a.welcareeligibleamount <= 1400 then 'l1201 to 1400'
                  when a.welcareeligibleamount > 1400 and a.welcareeligibleamount <= 1600 then 'm1401 to 1600'
                  when a.welcareeligibleamount > 1600 and a.welcareeligibleamount <= 1800 then 'n1601 to 1800'
                  when a.welcareeligibleamount > 1800 and a.welcareeligibleamount <= 2000 then 'o1801 to 2000'
                  when a.welcareeligibleamount > 2000 and a.welcareeligibleamount <= 3000 then 'p2001 to 3000'
                  when a.welcareeligibleamount > 3000 and a.welcareeligibleamount <= 4000 then 'q3001 to 4000'
                  when a.welcareeligibleamount > 4000 and a.welcareeligibleamount <= 5000 then 'r4001 to 5000'
                  when a.welcareeligibleamount > 5000 then 's5000 Higher'
               end Well_Eligible_group
               , a.policy_no
      from NPS_F3 a
      where a.welcareclaimcount >= 0
      ) b
group by b.Well_Eligible_group
order by b.Well_Eligible_group
;

-- group by Welcare claim paid amount
select b.well_reimbursement_grp, count(distinct b.policy_no) Policy_count
from (
      select case when a.welcarepaidamount >= 0 and a.welcarepaidamount <= 100 then 'a0 to 100'
                  when a.welcarepaidamount > 100 and a.welcarepaidamount <= 200 then 'b101 to 200'
                  when a.welcarepaidamount > 200 and a.welcarepaidamount <= 300 then 'c201 to 300'
                  when a.welcarepaidamount > 300 and a.welcarepaidamount <= 400 then 'd301 to 400'
                  when a.welcarepaidamount > 400 and a.welcarepaidamount <= 500 then 'e401 to 500'
                  when a.welcarepaidamount > 500 and a.welcarepaidamount <= 600 then 'f501 to 600'
                  when a.welcarepaidamount > 600 and a.welcarepaidamount <= 700 then 'g601 to 700'
                  when a.welcarepaidamount > 700 and a.welcarepaidamount <= 800 then 'h701 to 800'
                  when a.welcarepaidamount > 800 and a.welcarepaidamount <= 900 then 'i801 to 900'
                  when a.welcarepaidamount > 900 and a.welcarepaidamount <= 1000 then 'j901 to 1000'
                  when a.welcarepaidamount > 1000 and a.welcarepaidamount <= 1200 then 'k1001 to 1200'
                  when a.welcarepaidamount > 1200 and a.welcarepaidamount <= 1400 then 'l1201 to 1400'
                  when a.welcarepaidamount > 1400 and a.welcarepaidamount <= 1600 then 'm1401 to 1600'
                  when a.welcarepaidamount > 1600 and a.welcarepaidamount <= 1800 then 'n1601 to 1800'
                  when a.welcarepaidamount > 1800 and a.welcarepaidamount <= 2000 then 'o1801 to 2000'
                  when a.welcarepaidamount > 2000 and a.welcarepaidamount <= 3000 then 'p2001 to 3000'
                  when a.welcarepaidamount > 3000 and a.welcarepaidamount <= 4000 then 'q3001 to 4000'
                  when a.welcarepaidamount > 4000 and a.welcarepaidamount <= 5000 then 'r4001 to 5000'
                  when a.welcarepaidamount > 5000 then 's5000 Higher'
               end well_reimbursement_grp
               , a.policy_no
      from NPS_F1a a
      where a.welcareclaimcount > 0
      ) b
group by b.well_reimbursement_grp
order by b.well_reimbursement_grp
;
-- Group by Multy Insured Pets
select case when f1.total_pets >=7 then 7 else f1.total_pets end total_pets, count(*)
from NPS_F1A F1 -- CHANGE BETWEEN NPS_F1A, NPS_F2, NPS_F3
group by case when f1.total_pets >=7 then 7 else f1.total_pets end
order by case when f1.total_pets >=7 then 7 else f1.total_pets end
-- 382546 Total Policyholders
;

