Create Database Hopital_Admissions
use Hospital_Admissions_Mine

alter database Hopital_Admissions
modify name = Hospital_Admissions_Mine

Create Table Admissions_Clean
(
Patient_Id Varchar (250),
First_Name varchar (250),
Surname Varchar (250),
National_Id BigInt,
Date_Of_Birth datetime,
Disease Varchar (250),
Severity Varchar (250),
Admission_Status Varchar (250),
Ward Varchar (250),
Admission_Date datetime,
Discharge_Date datetime
)

--2.Clean and Insert data into Table
--I created a subquery to separate the insertion of data from the ranking logic, ranking logic allows me to make sure I make a rule based descision about the data. 
--This ensure I pull the first admission record at reception

Insert into [Hospital_Admissions_Mine].[dbo].[Admissions_Clean] 
Select
    Patient_Id, First_Name, surname, National_Id, Date_Of_Birth, 
    Disease, Severity, Admission_Status, Ward, Admission_Date, Discharge_Date
From (
    Select 
        Patient_Id, First_Name, surname, National_Id, Date_Of_Birth, 
        Disease, Severity, Admission_Status, Ward, Admission_Date, Discharge_Date,
        ROW_NUMBER() Over (
            Partition by Patient_Id 
            Order by Admission_Date desc
        ) as rn
    From [Hospital_Admissions_Mine].[dbo].[hospital_admissions_raw]
) as CleanedSubquery 
Where rn = 1
and not exists (
select 1 
from [Hospital_Admissions_Mine].[dbo].[Admissions_Clean] ac
where ac.patient_id = CleanedSubquery.patient_id)
Go

Select *
From [Hospital_Admissions_Mine].[dbo].[hospital_admissions_raw]
order by patient_id asc

Select *
From [Hospital_Admissions_Mine].[dbo].[Admissions_Clean]

--4.Questions
--A. Data Quality and deduplication
--5.How many rows landed in the raw table and how many remained after the dedup? What does this tell you?
-- 108 records in the raw table
Select *
From [Hospital_Admissions_Mine].[dbo].[hospital_admissions_raw]
--100 in the clean table
Select *
From [Hospital_Admissions_Mine].[dbo].[Admissions_Clean]

--6. Write a query a query that finds every duplicate admission entry in the raw table before you dedupe it.

Select 
    Patient_Id, First_Name, surname, National_Id, Date_Of_Birth, 
    Disease, Severity, Admission_Status, Ward, Admission_Date, Discharge_Date
From (
    Select 
        Patient_Id, First_Name, surname, National_Id, Date_Of_Birth, 
        Disease, Severity, Admission_Status, Ward, Admission_Date, Discharge_Date,
        ROW_NUMBER() Over (
            Partition by Patient_Id 
            Order by Admission_Date asc
        ) as rn
    From [Hospital_Admissions_Mine].[dbo].[hospital_admissions_raw]
) as CleanedSubquery 
Where rn = 2;
Go

--7.Why is (patient_id, admission_date) the correct natural key here instead of patient_id alone? Give a scenario where deduping on patient_id alone would silently delete a legitimate admission.
--If a patient had come on three different days and using patient id would only identify the patient 
--and remove a recent entry where the patient had a high severity illness or was admitted to a ward

--8.One duplicate pair in this dataset differs only by ward casing ("ICU" vs "icu"). 
--What other kinds of nearduplicates (typos, whitespace, date format drift) could break a naive dedup query, and how would you guard against each?
-- I can't find the icu and ICU casting
-- Typo 1- OUTPATIENTS and Outpatients
-- Typo 2- CARDIAC WARD and Cardiac Ward
-- You would would use an SQL Code to correct the words

Update [Hospital_Admissions_Mine].[dbo].[Admissions_Clean]
Set Ward = Replace(Ward, 'OUTPATIENTS', 'Outpatients')
Where Ward LIKE '%OUTPATIENTS%';

Update [Hospital_Admissions_Mine].[dbo].[Admissions_Clean]
Set Ward = Replace(Ward, 'CARDIAC WARD', 'Cardiac Ward')
Where Ward LIKE '%CARDIAC WARD%';

--9.Write a query to prove, after your merge runs, that no (patient_id, admission_date) pair appears twice.
Select
    Patient_Id, First_Name, surname, National_Id, Date_Of_Birth, 
    Disease, Severity, Admission_Status, Ward, Admission_Date, Discharge_Date
From (
    Select 
        Patient_Id, First_Name, surname, National_Id, Date_Of_Birth, 
        Disease, Severity, Admission_Status, Ward, Admission_Date, Discharge_Date,
        ROW_NUMBER() Over (
            Partition by Patient_Id 
            Order by Admission_Date desc
        ) as rn
    From [Hospital_Admissions_Mine].[dbo].[hospital_admissions_raw]
) as CleanedSubquery 
Where rn = 1;
Go

Select 
    Patient_Id, First_Name, surname, National_Id, Date_Of_Birth, 
    Disease, Severity, Admission_Status, Ward, Admission_Date, Discharge_Date
From (
    Select 
        Patient_Id, First_Name, surname, National_Id, Date_Of_Birth, 
        Disease, Severity, Admission_Status, Ward, Admission_Date, Discharge_Date,
        ROW_NUMBER() Over (
            Partition by Patient_Id 
            Order by Admission_Date asc
        ) as rn
    From [Hospital_Admissions_Mine].[dbo].[hospital_admissions_raw]
) as CleanedSubquery 
Where rn = 2;
Go
--or
Select count(Patient_Id) as Patients_In_Clean_Table, Patient_Id
From [Hospital_Admissions_Mine].[dbo].[Admissions_Clean]
Group by Patient_Id
Order by Patients_In_Clean_Table

Select count(Patient_Id) as Patients_In_Raw_Table, patient_id
From [Hospital_Admissions_Mine].[dbo].[hospital_admissions_raw]
Group by Patient_Id
Having count(Patient_Id) = 2
Order by Patients_In_Raw_Table

--B. Clinical / operational questions
--10. What is the admission rate (Admitted vs Not Admitted) for each severity level (low / medium / high)?
Select Severity, Count(case when Admission_Status = 'Admitted' then 1 end) as Admitted_per_Status,
Count(case when Admission_Status = 'Not Admitted' then 1 end) as Not_Admitted_per_Status
From [Hospital_Admissions_Mine].[dbo].[Admissions_Clean]
Group by Severity
Order by Admitted_per_Status, Not_Admitted_per_Status

--11. Which disease has the highest number of admitted patients?
Select Count(Disease) as Number_of_Admissions_Disease, Disease
From [Hospital_Admissions_Mine].[dbo].[Admissions_Clean]
Group by Disease
Order by Number_of_Admissions_Disease Desc

--12. Which ward has the most admissions, and does that match what you'd expect given the severity mix?
Select count(ward) as Number_of_Patients,Ward,Severity
From [Hospital_Admissions_Mine].[dbo].[Admissions_Clean]
Group by Ward, Severity
Order by Number_of_Patients Desc
--No, most people who are not admitted into a ward do not need to be admitted as the severity is low, however there are a few medium severity that are not admitted when they should be

--13. What is the average length of stay (discharge_date − admission_date) by severity level?
Select Avg(Datediff(day,admission_date,discharge_date)) as Avg_Days_Severity,Severity
From [Hospital_Admissions_Mine].[dbo].[Admissions_Clean]
Group By Severity
Order by Avg_Days_Severity desc

--14. Are there any patients marked 'Not Admitted' despite having a high severity disease? 
--Is that a data quality issue, a business rule exception, or something to flag to a clinician?
Select Admission_Status, Severity, Disease
From [Hospital_Admissions_Mine].[dbo].[Admissions_Clean]
where Admission_Status = 'Not Admitted' and Severity = 'high'
Group by Severity,Admission_Status, disease
Order by Disease

Select Admission_Status, Severity, Disease
From [Hospital_Admissions_Mine].[dbo].[Admissions_Clean]
where Admission_Status = 'Not Admitted' and Severity = 'medium'
Group by Severity,Admission_Status, disease
Order by Disease
--No high severity status diseases however there are medium status diseases that have not been admitted, when there are other instances of the same disease where they have been admitted
--This is something to flag to a clinician
--Code below for compaison
Select Disease, Severity, Admission_Status
From [Hospital_Admissions_Mine].[dbo].[Admissions_Clean]
Group by Disease,Severity, Admission_Status

--15. What is the age (from date_of_birth) distribution of admitted patients? Is any age group over or underrepresented?
Select Datediff(year,Date_Of_Birth,admission_date) as Ages, 
Count(case when Admission_Status = 'Admitted' then 1 end) as Admitted_per_Status,
Count(case when Admission_Status = 'Not Admitted' then 1 end) as Not_Admitted_per_Status
From [Hospital_Admissions_Mine].[dbo].[Admissions_Clean]
Group By Admission_Status, Date_Of_Birth, Admission_Date
Order by Ages asc
--The age group 60-96, elderly people are generally high risk patients and would likely be admitted more often however there is only 1 admission per age in the age group 