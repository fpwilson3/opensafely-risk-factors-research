********************************************************************************
*
*	Do-file:		cr_create_analysis_dataset.do
*
*	Project:		Risk factors for poor outcomes in Covid-19
*
*	Programmed by:	Elizabeth Williamson
*
*	Data used:		Data in memory (from input.csv)
*
*	Data created:	egdata.dta
*
*	Other output:	None
*
********************************************************************************
*
*	Purpose:		This do-file creates the variables required for the 
*					main analysis and saves into a Stata dataset.
*  
********************************************************************************

cap log close
log using ./output/cr_analysis_dataset, replace t

*******************************************************************************
*!!!!!!NOTE ON CODE GENERATING FAKE DATA WHICH NEEDS TO BE REPLACED LATER!!!!!!
*
*1) 	chronic_kidney_disease
*		stroke_dementia
*		other_neuro
*
*	Remove "gen" commands under "generate some extra variables, additional risk factors" (around line 67)
*
*  	Remove the section TEMPORARY - generate fake data for chronic_kidney_disease, stroke_dementia, other_neuro
*		Under "Create binary comorbidity indices from dates" (around line 248)
*
*
*2) 	Fake hospitalisation outcome is generated under *FAKE OUTCOME DATA ~ line 110
*
*******************************************************************************

***********************************
*  Generate some extra variables  *
***********************************

*** This section won't be needed once real data is fully available


set seed 123489


* Smoking - only make up if not there!! 
label define smoke 1 "Never" 2 "Former" 3 "Current" .u "Unknown (.u)"

capture confirm string variable smoking_status
if _rc==0 {
	noi di "USING REAL Smoking"
	gen     smoke = 1  if smoking_status=="N"
	replace smoke = 2  if smoking_status=="E"
	replace smoke = 3  if smoking_status=="S"
	replace smoke = .u if smoking_status=="M"
	label values smoke smoke
}
else {
	capture confirm numeric variable smoking_status
	if _rc==0 {
		noi di "USING REAL Smoking, already numeric"
		rename smoking_status smoke
		label values smoke smoke
	}
	else {
	noi di "USING FAKE Smoking"
		
	gen     smoke = 1 if uniform()<0.3
	replace smoke = 2 if uniform()<0.6 & smoke==.
	replace smoke = 3 if uniform()<0.6 & smoke==.
	replace smoke = .u if smoke==.
	label values smoke smoke

	}
}


* Ethnicity 
label define ethnicity 1 "White"  2 "South Asian"  3 "Black"  4 "Other"  5 "Mixed" 6 "Not Stated"

* Ethnicity - only make up if not there!! 
capture confirm numeric variable ethnicity
if _rc==0 {
	noi di "USING REAL ETHNICITY"
	label values ethnicity ethnicity
}
else {
	capture confirm string variable ethnicity
	if _rc==0 {
		noi di "USING REAL ETHNICITY, not numeric"
	}
	else {
	noi di "USING FAKE ETHNICITY"
		
	gen     ethnicity = 1 if uniform()<0.3
	replace ethnicity = 2 if uniform()<0.2 & ethnicity==.
	replace ethnicity = 3 if uniform()<0.1 & ethnicity==.
	replace ethnicity = 4 if uniform()<0.1 & ethnicity==.
	replace ethnicity = 5 if uniform()<0.1 & ethnicity==.
	replace ethnicity = 6 if ethnicity==.
	label values ethnicity ethnicity

	}
}


* Additional risk factors
gen chronic_kidney_disease = .
*gen stroke_dementia = .
*gen other_neuro = .

/* BMI (?now present for real)
replace bmi = rnormal(30, 15)
replace bmi = . if bmi<= 15
* SBP and DBP  (?now present for real)
replace bp_sys   = rnormal(110, 15)
replace bp_dias  = rnormal(80, 15)
*/

/* Gen STP
gen stp_temp = runiform()
egen stp = cut(stp_temp), group(40)
drop stp_temp
*/


****** THIS NEXT LITTLE SECTION WILL BE NEEDED FOR THE REAL DATA ******

*** Dates   

* Date of cohort entry, 1 Feb 2020
gen enter_date = date("01/02/2020", "DMY")
format enter_date %td

* Date of study end (typically: last date of outcome data available)
gen ecdseventcensor_date 		= date("21/04/2020", "DMY")
gen ituadmissioncensor_date 	= date("20/04/2020", "DMY") 
gen cpnsdeathcensor_date		= date("16/04/2020", "DMY")
gen onscoviddeathcensor_date 	= date("06/04/2020", "DMY")

format ecdseventcensor_date cpnsdeathcensor_date 	///
	onscoviddeathcensor_date ituadmissioncensor_date %td


***** Outcomes (real)

* ITU admission, CPNS death, ONS-covid death
foreach var of varlist died_date_ons died_date_cpns {
	confirm string variable `var'
	rename `var' `var'_dstr
	gen `var' = date(`var'_dstr, "YMD")
	drop `var'_dstr
}
gen cpnsdeath = (died_date_cpns < .)
gen died_date_onscovid = died_date_ons if died_ons_covid_flag_any==1
gen onscoviddeath = (died_date_onscovid < .)

* ITU admission
confirm string variable icu_date_admitted
assert icu == (icu_date_admitted!="")
rename icu ituadmission
gen itu_date = date(icu_date_admitted, "YMD")


****** END OF SECTION NEEDED FOR THE REAL DATA ******

*FAKE OUTCOME DATA
* ECDS event
gen ecdsevent = uniform()<0.20

gen lag = min(died_date_ons, died_date_cpns, ecdseventcensor_date) - enter_date

gen ecdsevent_date = enter_date + runiform()*lag
replace ecdsevent_date = . if ecdsevent==0
format ecdsevent_date %td

drop lag




****************************
*  Create required cohort  *
****************************

* Age: Exclude children
drop if age<18

* Age: Exclude those with implausible ages
assert age<.
drop if age>105

* Sex: Exclude categories other than M and F
assert inlist(sex, "M", "F", "I", "U")
drop if inlist(sex, "I", "U")




******************************
*  Convert strings to dates  *
******************************

* To be added: dates related to outcomes
foreach var of varlist 	bp_sys_date 					///
						bp_dias_date 					///
						bmi_date_measured				///
						chronic_respiratory_disease 	///
						chronic_cardiac_disease 		///
						diabetes 						///
						lung_cancer 					///
						haem_cancer						///
						other_cancer 					///
						bone_marrow_transplant 			///
						chemo_radio_therapy 			///
						chronic_liver_disease 			///
						stroke							///
						dementia		 				///
						other_neuro 					///
						chronic_kidney_disease 			///
						organ_transplant 				///	
						dysplenia						///
						sickle_cell 					///
						aplastic_anaemia 				///
						hiv 							///
						genetic_immunodeficiency 		///
						immunosuppression_nos 			///
						ra_sle_psoriasis  {
	capture confirm string variable `var'
	if _rc!=0 {
		assert `var'==.
		rename `var' `var'_date
	}
	else {
		replace `var' = `var' + "-15"
		rename `var' `var'_dstr
		replace `var'_dstr = " " if `var'_dstr == "-15"
		gen `var'_date = date(`var'_dstr, "YMD") 
		order `var'_date, after(`var'_dstr)
		drop `var'_dstr
	}
	format `var'_date %td
}

rename bmi_date_measured_date bmi_date_measured
rename bp_dias_date_measured_date  bp_dias_date
rename bp_sys_date_measured_date   bp_sys_date

* NB: Some BMI dates in future or after cohort entry



**************************************************
*  Create binary comorbidity indices from dates  *
**************************************************

* Comorbidities ever before
foreach var of varlist	chronic_respiratory_disease_date 	///
						chronic_cardiac_disease_date 		///
						diabetes 							///
						lung_cancer_date 					///
						haem_cancer_date					///
						other_cancer_date 					///
						bone_marrow_transplant_date 		///
						chemo_radio_therapy_date			///
						chronic_liver_disease_date 			///
						stroke_date							///
						dementia_date						///
						other_neuro_date					///
						chronic_kidney_disease_date 		///
						organ_transplant_date 				///
						dysplenia_date 						///
						sickle_cell_date 					///
						hiv_date							///
						genetic_immunodeficiency_date		///
						ra_sle_psoriasis_date   {
	local newvar =  substr("`var'", 1, length("`var'") - 5)
	gen `newvar' = (`var'< d(1/2/2020))
	order `newvar', after(`var')
}


/* Grouped comorbidities  */

* Stroke and dementia
egen stroke_dementia = rowmax(stroke dementia)
order stroke_dementia, after(dementia_date)

* Cancer except haematological 
gen lung_cancer_lastyr  = inrange(lung_cancer_date,  d(1/2/2019), d(1/2/2020))
gen other_cancer_lastyr = inrange(other_cancer_date, d(1/2/2019), d(1/2/2020))
egen cancer_exhaem_lastyr = rowmax(lung_cancer_lastyr other_cancer_lastyr)

* Haem malig, aplastic anaemia, bone marrow transplant
gen haem_cancer_lastyr 				= inrange(haem_cancer_date,		  		d(1/2/2019), d(1/2/2020))
gen aplanaemia_lastyr  				= inrange(aplastic_anaemia_date,  		d(1/2/2019), d(1/2/2020))
gen bone_marrow_transplant_lastyr  	= inrange(bone_marrow_transplant_date,  d(1/2/2019), d(1/2/2020))
egen haemmalig_aanaem_bmtrans_lastyr = ///
	rowmax(haem_cancer_lastyr aplanaemia_lastyr bone_marrow_transplant_lastyr)
 
order 	lung_cancer_lastyr 				///
		other_cancer_lastyr 			///
		haem_cancer_lastyr 				///
		aplanaemia_lastyr 				///
		bone_marrow_transplant_lastyr 	///
		cancer_exhaem_lastyr 			///
		haemmalig_aanaem_bmtrans_lastyr, after(other_cancer)

* Spleen problems (dysplenia/splenectomy/etc and sickle cell disease)   
egen spleen = rowmax(dysplenia sickle_cell) 
order spleen, after(sickle_cell)

*********************   TO BE REMOVED FOR REAL DATA     *******************************************

* TEMPORARY - generate fake data for chronic_kidney_disease
for var chronic_kidney_disease : replace X = uniform()<0.05

***************************************************************************************************


* Immunosuppressed:
* HIV, dysplenia/sickle-cell, genetic conditions ever, OR
* aplastic anaemia, haematological malignancies, bone marrow transplant, 
*   chemo/radio in last year, OR
* immunosuppression NOS in last 3 months
gen temp1  = max(hiv, spleen, genetic_immunodeficiency)
gen temp2  = inrange(immunosuppression_nos_date,    d(1/11/2019), d(1/2/2020))
gen temp3  = max(inrange(aplastic_anaemia_date, 	 d(1/2/2019), d(1/2/2020)), ///
				inrange(haem_cancer_date, 			 d(1/2/2019), d(1/2/2020)), ///			
				inrange(bone_marrow_transplant_date, d(1/2/2019), d(1/2/2020)), ///
				inrange(chemo_radio_therapy_date, 	 d(1/2/2019), d(1/2/2020))) 
egen immunosuppressed = rowmax(temp1 temp2 temp3)
drop temp1 temp2 temp3
order immunosuppressed, after(immunosuppression_nos)





********************************
*  Recode and check variables  *
********************************

* Sex
assert inlist(sex, "M", "F")
gen male = sex=="M"
drop sex

* BMI 
* Only keep if within certain time period?
* bmi_date_measured
* Set implausible BMIs to missing:
replace bmi = . if !inrange(bmi, 15, 50)


/*
* Smoking 
assert inlist(smoking_status, "N", "E", "S", "M")
gen     smoke = 1 if smoking_status=="N"
replace smoke = 2 if smoking_status=="E"
replace smoke = 3 if smoking_status=="S"
replace smoke = .u if smoking_status==""
label define smoke 1 "Never" 2 "Former" 3 "Current" .u "Unknown (.u)"
label values smoke smoke
drop smoking_status
*/

/* Ethnicity
rename ethnicity ethnicity_o
assert inlist(ethnicity, "A", "B", "W", "M", "O", "U")
gen     ethnicity = 1 if ethnicity_o=="W"
replace ethnicity = 2 if ethnicity_o=="B"
replace ethnicity = 3 if ethnicity_o=="A"
replace ethnicity = 4 if ethnicity_o=="M"
replace ethnicity = 5 if ethnicity_o=="O"
replace ethnicity = .u if ethnicity_o=="U"
label define ethnicity 1 "White" 2 "Black" 3 "Asian" 4 "Mixed" 5 "Other" .u "Unknown (.u)"
label values ethnicity ethnicity
drop ethnicity_o
*/



**************************
*  Categorise variables  *
**************************


/*  Age variables  */ 

* Create categorised age
recode age 18/39.9999=1 40/49.9999=2 50/59.9999=3 ///
	60/69.9999=4 70/79.9999=5 80/max=6, gen(agegroup) 

label define agegroup 	1 "18-<40" ///
						2 "40-<50" ///
						3 "50-<60" ///
						4 "60-<70" ///
						5 "70-<80" ///
						6 "80+"
label values agegroup agegroup


* Create binary age
recode age min/69.999=0 70/max=1, gen(age70)

* Check there are no missing ages
assert age<.
assert agegroup<.
assert age70<.

* Create restricted cubic splines fir age
mkspline age = age, cubic nknots(4)


/*  Body Mass Index  */

* BMI (NB: watch for missingness)
gen 	bmicat = .
recode  bmicat . = 1 if bmi<18.5
recode  bmicat . = 2 if bmi<25
recode  bmicat . = 3 if bmi<30
recode  bmicat . = 4 if bmi<35
recode  bmicat . = 5 if bmi<40
recode  bmicat . = 6 if bmi<.
replace bmicat = .u if bmi>=.

label define bmicat 1 "Underweight (<18.5)" 	///
					2 "Normal (18.5-24.9)"		///
					3 "Overweight (25-29.9)"	///
					4 "Obese I (30-34.9)"		///
					5 "Obese II (35-39.9)"		///
					6 "Obese III (40+)"			///
					.u "Unknown (.u)"
label values bmicat bmicat

* Create binary BMI (NB: watch for missingness; add 7=0)
recode bmicat 6=1 .u 1/5=0, gen(obese40)
order obese40, after(bmicat)



/*  Smoking  */

* Create non-missing binary variable for current smoking
recode smoke 3=1 1/2 .u=0, gen(currentsmoke)
order currentsmoke, after(smoke)


/*  Blood pressure  */

* Categorise
gen     bpcat = 1 if bp_sys < 120 &  bp_dias < 80
replace bpcat = 2 if inrange(bp_sys, 120, 130) & bp_dias<80
replace bpcat = 3 if inrange(bp_sys, 130, 140) | inrange(bp_dias, 80, 90)
replace bpcat = 4 if (bp_sys>=140 & bp_sys<.) | (bp_dias>=90 & bp_dias<.) 
replace bpcat = .u if bp_sys>=. | bp_dias>=.

label define bpcat 1 "Normal" 2 "Elevated" 3 "High, stage I"	///
					4 "High, stage II" .u "Unknown"
label values bpcat bpcat

* Create non-missing indicator of known high blood pressure
gen bphigh = (bpcat==3 | bpcat==4)
order bpcat bphigh, after(bp_dias_date)




/*  IMD  */

* Group into 5 groups
rename imd imd_o
egen imd = cut(imd), group(5) icodes
replace imd = imd + 1

replace imd = .u if imd_o==-1
drop imd_o
label define imd 1 "1" 2 "2" 3 "3" 4 "4" 5 "5" .u "Unknown"
label values imd imd 




/*  Centred age, sex, IMD, ethnicity (for adjusted KM plots)  */ 

* Centre age (linear)
summ age
gen c_age = age-r(mean)

* "Centre" sex to be coded -1 +1 
recode male 0=-1, gen(c_male)

* "Centre" IMD
gen c_imd = imd - 3

* "Centre" ethnicity
gen c_ethnicity = ethnicity - 3




************************
*  Make numeric STP    *
************************

bysort geographic_area: gen stp = 1 if _n==1
replace stp = sum(stp)




********************************
*  Outcomes and survival time  *
********************************

/*  Create survival times  */

* For looping later, name must be stime_binary_outcome_name

* Survival time = last followup date (first: end study, death, or that outcome)
gen stime_ecdsevent  	= min(ecdseventcensor_date, 	ecdsevent_date, died_date_ons)
gen stime_ituadmission 	= min(ituadmissioncensor_date, 	itu_date, 		died_date_ons)
gen stime_cpnsdeath  	= min(cpnsdeathcensor_date, 	died_date_cpns, died_date_ons)
gen stime_onscoviddeath = min(onscoviddeathcensor_date, 				died_date_ons)

* If outcome was after censoring occurred, set to zero

********** NB MIGHT WANT TO REVISIT THIS ****************************************

replace ecdsevent 		= 0 if (ecdsevent_date		> ecdseventcensor_date) 
replace ituadmission 	= 0 if (itu_date			> ituadmissioncensor_date) 
replace cpnsdeath 		= 0 if (died_date_cpns		> cpnsdeathcensor_date) 
replace onscoviddeath 	= 0 if (died_date_onscovid	> onscoviddeathcensor_date) 

format %d stime*
format %d ecdsevent_date itu_date died_date_onscovid died_date_ons died_date_cpns 



*********************
*  Label variables  *
*********************

* Demographics
label var patient_id		"Patient ID"
label var age 				"Age (years)"
label var agegroup			"Grouped age"
label var age70 			"70 years and older"
label var male 				"Male"
label var bmi 				"Body Mass Index (BMI, kg/m2)"
label var bmicat 			"Grouped BMI"
label var bmi_date  		"Body Mass Index (BMI, kg/m2), date measured"
label var obese40 			"Severely obese (cat 3)"
label var smoke		 		"Smoking status"
label var currentsmoke	 	"Current smoker"
label var imd 				"Index of Multiple Deprivation (IMD)"
label var ethnicity			"Ethnicity"
label var stp 				"Sustainability and Transformation Partnership"

label var bp_sys 			"Systolic blood pressure"
label var bp_sys_date 		"Systolic blood pressure, date"
label var bp_dias 			"Diastolic blood pressure"
label var bp_dias_date 		"Diastolic blood pressure, date"
label var bpcat 			"Grouped blood pressure"
label var bphigh			"Binary high (stage 1/2) blood pressure"

label var age1 				"Age spline 1"
label var age2 				"Age spline 2"
label var age3 				"Age spline 3"
label var c_age				"Centred age"
label var c_male 			"Centred sex (code: -1/+1)"
label var c_imd				"Centred Index of Multiple Deprivation (values: -2/+2)"
label var c_ethnicity		"Centred ethnicity (values: -2/+2)"

* Comorbidities
label var chronic_respiratory_disease	"Respiratory disease (excl. asthma)"
label var asthma						"Asthma"
label var chronic_cardiac_disease		"Heart disease"
label var diabetes						"Diabetes"
label var lung_cancer					"Lung cancer"
label var haem_cancer					"Haem. cancer"
label var other_cancer					"Any cancer"
label var lung_cancer_lastyr			"Lung cancer in last year"
label var other_cancer_lastyr			"Cancer other than lung/haematological in last year"
label var cancer_exhaem_lastyr 			"Cancer other than haematological in last year"
label var haem_cancer_lastyr			"Haem. cancer in last year"
label var aplanaemia_lastyr 			"Aplastic anaemia in last year"
label var bone_marrow_transplant_lastyr "Bone marrow transplant in last year"
label var haemmalig_aanaem_bmtrans_lastyr "Haematol malignancy, aplastic anaemia or bone marrow transplant in last year"
label var bone_marrow_transplant		"Bone marrow transplant"
label var chronic_liver_disease			"Chronic liver disease"
label var stroke_dementia				"Stroke or dementia"
label var other_neuro					"Neuro condition other than stroke/dementia"	
label var chronic_kidney_disease 		"Kidney disease"
label var organ_transplant 				"Organ transplant recipient"
label var dysplenia						"Dysplenia (splenectomy, other, not sickle cell)"
label var sickle_cell 					"Sickle cell"
label var spleen						"Spleen problems (dysplenia, sickle cell)"
label var ra_sle_psoriasis				"RA, SLE, Psoriasis (autoimmune disease)"
label var chemo_radio_therapy			"Chemotherapy or radiotherapy"
label var aplastic_anaemia				"Aplastic anaemia"
label var hiv 							"HIV"
label var genetic_immunodeficiency 		"Genetic immunodeficiency"
label var immunosuppression_nos 		"Other immunosuppression"
label var immunosuppressed				"Immunosuppressed (combination algorithm)"
 label var chronic_respiratory_disease_date	"Respiratory disease (excl. asthma), date"
label var chronic_cardiac_disease_date	"Heart disease, date"
label var diabetes_date					"Diabetes, date"
label var lung_cancer_date				"Lung cancer, date"
label var haem_cancer_date				"Haem. cancer, date"
label var other_cancer_date				"Any cancer, date"
label var bone_marrow_transplant_date	"Organ transplant, date"
label var chronic_liver_disease_date	"Liver, date"
label var stroke_date					"Stroke, date"
label var dementia_date					"Dementia, date"
label var other_neuro_date				"Neuro condition other than stroke/dementia, date"	
label var chronic_kidney_disease_date 	"Kidney disease, date"
label var organ_transplant_date			"Organ transplant recipient, date"
label var dysplenia_date				"Splenectomy etc, date"
label var sickle_cell_date 				"Sickle cell, date"
label var ra_sle_psoriasis_date			"RA, SLE, Psoriasis (autoimmune disease), date"
label var chemo_radio_therapy_date		"Chemotherapy or radiotherapy, date"
label var aplastic_anaemia_date			"Aplastic anaemia, date"
label var hiv_date 						"HIV, date"
label var genetic_immunodeficiency_date "Genetic immunodeficiency, date"
label var immunosuppression_nos_date 	"Other immunosuppression, date"

* Outcomes and follow-up
label var enter_date				"Date of study entry"
label var ecdseventcensor_date		"Date of admin censoring for ecds"
label var ituadmissioncensor_date 	"Date of admin censoring for itu admission (icnarc)"
label var cpnsdeathcensor_date 		"Date of admin censoring for cpns deaths"
label var onscoviddeathcensor_date 	"Date of admin censoring for ONS deaths"

label var ecdsevent			"Failure/censoring indicator for outcome: ECDS event"
label var ituadmission		"Failure/censoring indicator for outcome: ITU admission"
label var cpnsdeath			"Failure/censoring indicator for outcome: CPNS covid death"
label var onscoviddeath		"Failure/censoring indicator for outcome: ONS covid death"

* Survival times
label var  stime_ecdsevent		"Survival time; outcome ECDS event"
label var  stime_ituadmission	"Survival time; outcome ITU admission"
label var  stime_cpnsdeath 		"Survival time; outcome CPNS covid death"
label var  stime_onscoviddeath 	"Survival time; outcome ONS covid death"

*REDUCE DATASET SIZE TO VARIABLES NEEDED
keep patient_id imd stp enter_date  										///
	ituadmission itu_date ituadmissioncensor_date stime_ituadmission		///
	ecdsevent ecdsevent_date ecdseventcensor_date stime_ecdsevent			///
	cpnsdeath died_date_cpns cpnsdeathcensor_date stime_cpnsdeath			///
	onscoviddeath onscoviddeathcensor_date died_date_ons died_date_onscovid ///
	stime_onscoviddeath														///
	age agegroup age70 age1 age2 age3 male bmi smoke currentsmoke 			///
	bpcat bphigh bmicat obese40 ethnicity 									///
	chronic_respiratory_disease asthma chronic_cardiac_disease 				///
	diabetes cancer_exhaem_lastyr haemmalig_aanaem_bmtrans_lastyr 			///
	chronic_liver_disease organ_transplant spleen ra_sle_psoriasis 			///
	chronic_kidney_disease stroke dementia stroke_dementia other_neuro   	


***************
*  Save data  *
***************

sort patient_id
label data "Poor factors dummy analysis dataset"
save "egdata", replace


log close
