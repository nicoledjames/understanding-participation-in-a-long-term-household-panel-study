/*====================================================================
Understanding Participation in a Long-Term Household Panel Study: 
Evidence from the UK 
PhD Thesis

Nicole D James 
----------------------------------------------------------------------
Chapter:			1
Do File:			01_data_management_2.do 
Task: 				Recode variables (after LCA)
----------------------------------------------------------------------
Creation Date:		13 Jan 2020
Modification Date: 	19 Mar 2021
Do-file version:	02
====================================================================*/

cap log close 
log using "$logfiles\01_data_management_2.do", replace t 

/*====================================================================
                        1: Merge LCA Data
====================================================================*/
qui {
	use "$datasets\merged.dta", clear 
	preserve 
		import delim "$latent_gold\results\final_model_1.csv" , clear varnames(1)
		keep pidp clu 
		ren clu clu_1
		tempfile clu_1
		save `clu_1' 
	restore
	merge 1:1 pidp using `clu_1', keep(1 3) nogen assert(3)
	save "$wdata\bhps_data.dta", replace

}

/*====================================================================
                        1: Initial Recodes 
====================================================================*/
qui {
	use "$wdata\bhps_data.dta", clear

	/* ind int start year missing from BW1*/ 
	n fre ba_istrtdatm
	g ba_istrtdaty = 1991, b(bb_istrtdaty) // interviews from sept-dec 91 
	g ba_intdatey = 1991, a(ba_intdatem)
	n fre *istrtdaty

	g lwint = .
	la var lwint "Last wave R had full interview" 
	foreach x of global revlist2 { 
		replace lwint = `x' if w`x'==1 & lwint==0
	} 
	n fre lwint

	/* female */
	n datacheck sex==sex_dv if sex_dv!=-20, varshow(pidp sex sex_dv) noobs nolabel
	n fre sex 
	g female=(sex==2)
	la var female "Female" 
	n fre female

	/* age */
	g age=(ba_age_dv) 
	/* some people aged 15 who did a full adult interview at w1, appears as 15 
	 because of how age is calculated but would've been 16 to do an adult int */
	replace age = 16 if age==15 
	la var age "Age at W1" 

	recode age (16/19 = 1) (20/24 = 2) (25/34 = 3) (35/44 = 4) (45/54 = 5) ///
		(55/64 = 6) (65/max = 7), gen(agegrp7) 
	la var agegrp7 "Age"
	la def agegrp7 1 "16-19" 2 "20-24" 3 "25-34" 4 "35-44" 5 "45-54" ///
		6 "55-64" 7 "65+", modify 
	la val agegrp7 agegrp7
	n fre agegrp7

	/* gen health */
	n fre *hlstat // in all bhps waves except for w9, w14
	n fre b?_hlsf1 // in w9, w14 
	n fre *sf1 // w2-8

	/*hlstat asked in normal interview, so use sf1 and fill in missings with 
	scsf1*/
	forval i = 2/$wn1 { 
		loc w = substr("abcdefghijklmnopqrstuvwxyz", `i',1) + "_"
		g `w'genhealth = `w'sf1 
		replace `w'genhealth = `w'scsf1 if ///
			!inrange(`w'genhealth,1,5) & inrange(`w'scsf1,1,5) 
		n fre `w'genhealth
	}
	isvar *scsf1 ?_scf1
	cap drop `r(varlist)' 
	ren *hlstat *genhealth
	ren b?_hlsf1 b?_genhealth 

	/* hh net income*/
	/* ------------------------------------------------------ */
	/* Validity Check: those with mi mod. oecd should have missing hh income */
	forval i = 1/18 { 
		loc w = "b" + substr("abcdefghijklmnopqr", `i',1) + "_"
		n datacheck `w'hhneti==-9 if `w'eq_moecd==-9, ///
			varshow(pidp `w'hhneti `w'eq_moecd) noobs nolabel
	}
	/* ------------------------------------------------------ */

	preserve 
		import delim "$input\table_36_rpi_annual_average.csv", clear ///
			varnames(1) case(l)
		save "$wdata\rpi", replace
	restore 

	/* BHPS */
	forval i=1/18 { 
		loc w = "b" + substr("abcdefghijklmnopqr", `i',1) + "_"

		/* marital */
		recode `w'mastat (0 = 0) (6 = 1) (1 7 3 = 2) (5 9 = 3) ///
			(4 8 =4) (3 10 = 5), g(`w'marital)
		mvdecode `w'marital, mv(-1/-9 = .a)
		la var `w'marital "marital status - recoded" 
		la def `w'marital ///
			0 "child" 1 "single, never married" ///
			2 "married/cohab (incl. CP)" /// 
			4 "separated (incl. CP)" ///
			4 "divorced (incl. CP)" /// 
			5 "widowed (incl. CP)", modify 
		la val `w'marital `w'marital
		n fre `w'marital 
		
		/* job status */ 	
		recode `w'jbstat (6 = 5) (7 9 11 = 6) (8 = 7) (9 10 97 = 8), g(`w'job)
		mvdecode `w'job, mv(-1/-9 = .a) 
		la var `w'job "Job Status" 
		la def `w'job ///
			1 "self emp." ///
			2 "emp." ///
			3 "unemp." ///
			4 "retired" ///
			5 "mat/fam care" ///
			6 "stu/appren/train" ///
			7 "lt sick/disa" ///
			8 "other"
		la val `w'job `w'job 
		n fre `w'job 
		
		/* job status 2 */ 
		recode `w'jbstat (1 2 5 7 9 11 = 1) (3 = 2) (4 = 3) ///
			(6 8 9 10 97 = 4), g(`w'job2)
		mvdecode `w'job2, mv(-1/-9 = .a) 
		la var `w'job2 "Job Status" 
		la def `w'job2 ///
			1 "Employed, in education or training" ///
			2 "Unemployed" ///
			3 "Retired" ///
			4 "Other"
		la val `w'job2 `w'job2
		n fre `w'job2 
		
		/* hh net income */ 
		mvdecode `w'hhneti `w'eq_moecd, mv(-9)
		g `w'hhneti2 = ((`w'hhneti*52)/12) // BHPS hh net inc measured weekly - convert to monthly
		g `w'hhneti_oecd = `w'hhneti2/`w'eq_moecd // adjust for hhsize & composition
		replace `w'hhneti_oecd=. if inlist(ivfio`i',12,99) // no longer in the hh 
		replace `w'istrtdaty = `w'intdatey ///
			if mi(`w'istrtdaty) & inlist(ivfio`i',9) & ///
			(!mi(`w'intdatey) & !inlist(`w'intdatey,-9,-8,-2,-1)) // replace ind int sdate with hh int sdate if ivfio==lost on laptop
		n datacheck !mi(`w'istrtdaty) & !inlist(`w'istrtdaty,-9,-8,-1,-2,-7)  ///
			if !mi(`w'hhneti_oecd) & !inlist(`w'hhneti_oecd,-9), noobs nolabel ///
			message(Wave `i') varshow(pidp ivfio`i' `w'istrtdaty `w'hhneti_oecd) 
		if inrange(`i',2,18) {
			preserve 
				use "$wdata\rpi", clear 
				ren year `w'istrtdaty
				ren rpi_annual_average `w'rpi 
				tempfile rpi`i'
				save `rpi`i''
			restore 
			
			merge m:1 `w'istrtdaty using `rpi`i'', keep(1 3) nogen 
			g `w'hhneti_adj = (`w'hhneti_oecd * (133.5/`w'rpi)) // rpi adj. formula = income*(rpi_1991/rpi_X) 
		}
		else g `w'hhneti_adj = `w'hhneti_oecd // other waves will be adjusted to bw1 
		
		g `w'hhneti_adj2 = `w'hhneti_adj/1000 // change unit to 1000s of £ 
		
		/* dwelling */
		if inrange(`i',1,4) recode `w'hstype (1/4 = 1) (5/6 = 2) (0 7/12 = 3) ///
			(13 = .a), g(`w'dwelling) 
		if inrange(`i',5,18) recode `w'hstype (1/4 = 1) (5/8 = 2) (9/15 = 3), ///
			g(`w'dwelling)
		mvdecode `w'dwelling, mv(-1/-9 = .a) 
		la var `w'dwelling "Dwelling type"
		la def `w'dwelling ///
			1 "Own entrance" ///
			2 "Flats and other multi-storey units" ///
			3 "Bedsits/institutions/other structures", modify 
		la val `w'dwelling `w'dwelling
		n fre `w'dwelling
		
		/* distance moved */
		if inrange(`i',2,18) {
			g `w'distmov2 = (`w'distmov>0 & !mi(`w'distmov))
			n fre `w'distmov2
			la var `w'distmov2 "moved flag" 
			la val `w'distmov2 `w'distmov2
		}
		
		/* political party support */ 
		recode `w'vote1 (2 = 0) (-9/-1=.), g(`w'polparsup)
		la var `w'polparsup "Supports a political party"
		n fre `w'polparsup
		
		/* organisation member */ 
		if inrange(`i',1,5) | inlist(`i',7,9,11,13,15,17) {
			mvdecode `w'orgm*, mv(-9/-1)
			egen `w'orgm = rowtotal(`w'orgm*)
			n fre `w'orgm
		}
	}

	/* UKHLS */
	forval i = 2/$wn1 { 
		loc w = substr("abcdefghijklmnopqr", `i',1) + "_"
		loc j = `i'+17
		
		/* marital */
		recode `w'marstat (1 = 1) (2 3 = 2) (4 7 = 3) ///
			(5 8 = 4) (6 9 = 5), g(`w'marital)
		mvdecode `w'marital, mv(-1/-9 = .a)
		la var `w'marital "marital status - recoded" 
		la def `w'marital ///
			0 "child" 1 "single, never married" ///
			2 "married/cohab (incl. CP)" /// 
			3 "separated (incl. CP)" ///
			4 "divorced (incl. CP)" /// 
			5 "widowed (incl. CP)", modify 
		la val `w'marital `w'marital	
		n fre `w'marital 

		/* job status */
		recode `w'jbstat (6 = 5) (7 9 11 = 6) (8 = 7) (9 10 97 = 8), g(`w'job)
		mvdecode `w'job, mv(-1/-9 = .a) 
		la var `w'job "job status" 
		la def `w'job ///
			1 "self emp." ///
			2 "emp." ///
			3 "unemp." ///
			4 "retired" ///
			5 "mat/fam care" ///
			6 "stu/appren/train" ///
			7 "lt sick/disa" ///
			8 "other"
		la val `w'job `w'job 
		n fre `w'job 
		
		/* job status 2 */ 
		recode `w'jbstat (1 2 5 7 9 11 = 1) (3 = 2) (4 = 3) ///
			(6 8 9 10 97 = 4), g(`w'job2)
		mvdecode `w'job2, mv(-1/-9 = .a) 
		la var `w'job2 "Job status" 
		la def `w'job2 ///
			1 "Employed, in education or training" ///
			2 "Unemployed" ///
			3 "Retired" ///
			4 "Other"
		la val `w'job2 `w'job2
		n fre `w'job2 
		
		/* hh net income */ 
		mvdecode `w'fihhmnnet3_dv `w'ieqmoecd_dv, mv(-9) 
		g `w'hhneti_oecd = `w'fihhmnnet3_dv/`w'ieqmoecd_dv // adjust for hhsize & composition
		replace `w'hhneti_oecd=. if inlist(ivfio`j',12,99) // no longer in the hh 
		replace `w'istrtdaty = `w'intdatey ///
			if mi(`w'istrtdaty) & inlist(ivfio`i',9) & ///
			(!mi(`w'intdatey) & !inlist(`w'intdatey,-9,-8,-2,-1)) // replace ind int sdate with hh int sdate if ivfio==lost on laptop
		n datacheck !mi(`w'istrtdaty) & !inlist(`w'istrtdaty,-9,-8,-1,-2,-7)  ///
			if !mi(`w'hhneti_oecd) & !inlist(`w'hhneti_oecd,-9), noobs nolabel ///
			message(Wave `i') varshow(pidp ivfio`i' `w'istrtdaty `w'hhneti_oecd) 
		preserve 
			use "$wdata\rpi", clear 
			ren year `w'istrtdaty
			ren rpi_annual_average `w'rpi 
			tempfile rpi`i'
			save `rpi`i''
		restore 
		merge m:1 `w'istrtdaty using `rpi`i'', keep(1 3) nogen 
		g `w'hhneti_adj = (`w'hhneti_oecd * (133.5/`w'rpi)) // rpi adj. formula = income*(rpi_1991/rpi_X)
		g `w'hhneti_adj2 = `w'hhneti_adj/1000 // change unit to 1000s of £ 
		
		/* dwelling */
		recode `w'dweltyp (1/4 = 1) (5/8 = 2) (9/15 97 = 3), g(`w'dwelling)
		mvdecode `w'dwelling, mv(-1/-9 16 = .a) 
		la var `w'dwelling "dwelling type"
		la def `w'dwelling ///
			1 "own entrance" ///
			2 "flats and other multi-storey units" ///
			3 "bedsits/institutions/oth structures", modify 
		la val `w'dwelling `w'dwelling
		n fre `w'dwelling
		
		/* distance moved */
		if inrange(`i',3,${wn1}) {
			g `w'distmov2 = (`w'distmov_dv>0 & !mi(`w'distmov_dv))
			la var `w'distmov2 "moved flag" 
			la val `w'distmov2 `w'distmov2 
			n fre `w'distmov2
		}
		
		/* political party support */ 
		if `i'!=8 {
			recode `w'vote1 (2 = 0) (-9/-1=.), g(`w'polparsup)
			la var `w'polparsup "Supports a political party"
			n fre `w'polparsup
		}
		
		if inlist(`i',3,6,9) {
			mvdecode `w'orgm*, mv(-9/-1)
			egen `w'orgm = rowtotal(`w'orgm*)
			n fre `w'orgm
		}
	}

	save "$wdata\temp1", replace 
}
/*====================================================================
                        2: Last Known
====================================================================*/
qui {
	use "$wdata\temp1", clear

	loc lkvars_1 hhneti_adj2
	loc lkvars_2 scghq1_dv agechy_dv nchild_dv npens_dv orgm polparsup
	loc lkvars_3 marital hiqual_dv job job2 genhealth dwelling tenure_dv ///
		hhsize gor_dv vote6
	loc lkvars_4 distmov2

	/* Generate labelled placeholder vars */
	forval i = 1/4 { 
		foreach v of loc lkvars_`i' { 
			/* Copy labels from ba_* or bb_* */ 
			cap conf var ba_`v', exact 
			if !_rc loc l "a" 
			else loc l "b" 
			loc vlab: var label b`l'_`v'
			loc vllab: val lab b`l'_`v'
			
			if `i'==4 g `v' = 0 
			else g `v' = .
			la var `v' "`vlab'"
			la val `v' `vllab'
		}
	}

	/* Loop through waves in reverse and fill placeholders with last known value */
	foreach x of global revlist1 { 
		// zero == valid value & neg. numbers == valid 
		foreach y1 of loc lkvars_1 { 
			replace `y1' = `x'_`y1' ///
				if !(mi(`x'_`y1') | inlist(`x'_`y1',-9)) & mi(`y1')
		}
		// zero == valid value 
		foreach y2 of loc lkvars_2 { 
			cap conf var `x'_`y2', exact
			if !_rc replace `y2' = `x'_`y2' ///
				if (`x'_`y2'>=0 & !mi(`x'_`y2')) & (mi(`y2'))
		}
		
		// zero == missing value 
		foreach y3 of loc lkvars_3 { 
			cap conf var `x'_`y3', exact
			if !_rc replace `y3' = `x'_`y3' ///
				if (`x'_`y3'>0 & !mi(`x'_`y3')) & (mi(`y3'))
		}
		
		// combine 
		foreach y4 of loc lkvars_4 { 
			cap conf var `x'_`y4', exact
			if !_rc replace `y4' = `y4' + `x'_`y4' 	
		}
	} 

	g elig_chk=.
	foreach x of glo revlist2 { 
		replace elig_chk = `x' if inrange(ivfio`x',1,11) & mi(elig_chk)
	}
	n fre elig_chk

	save "$wdata\temp2", replace 
}

/*====================================================================
                        3: Checks and Labels 
====================================================================*/
qui {
	use "$wdata\temp2", clear 
	
	/* Sociodemographics */
	n fre ethn_dv
	recode ethn_dv (1 4 = 0) (5/97 = 1), gen(ethnmin)
	mvdecode ethnmin, mv(-1/-9 = .)
	la var ethnmin "Ethnic Minority"
	fre ethnmin

	la var marital "marital status" 
	la def marital ///
			0 "child" 1 "single" ///
			2 "married/cohab" /// 
			3 "separated" ///
			4 "divorced" /// 
			5 "widowed", modify 
	la val marital marital	
	n fre marital

	g partner = (marital==2) if !mi(marital)
	la var partner "Has Partner" 

	ta partner marital, m 

	n fre hiqual_dv
	recode hiqual_dv (9 = 0) (1 = 1) (2 = 2) (3 = 3) (4 = 4) (5 = 5), g(hiqual) 
	la var hiqual "Highest Qualification"
	la def hiqual ///
		0 "No qualification" ///
		1 "Degree" ///
		2 "Other higher degree" ///
		3 "A-Level etc." ///
		4 "GCSE etc." /// 
		5 "Other qualification", modify 
	la val hiqual hiqual
	n fre hiqual

	n fre job 
	n fre job2
	n ta job2 job

	ren scghq1_dv ghq
	la var ghq "Subjective wellbeing" 
	 
	n fre genhealth 
	la var genhealth "Self-rated General Health" 

	/* Community Attachment */ 
	ren vote6 polint // political interest 
	recode orgm (0=0) (1/2 = 1) (3/4=2) (5/max =3), g(orgm2)
	la def orgm2 ///
		0 "None" ///
		1 "1-2" ///
		2 "3-4" ///
		3 "5+", modify 
	la val orgm2 orgm2
	la var orgm2 "No. of Organisations Respondent is a Member of"
	n fre orgm2

	/* HH Composition */ 
	n fre agechy_dv 
	n fre ba_agechy_dv if mi(agechy_dv) 
	recode agechy_dv (0/3 = 1) (4/9 = 2) (10/15 = 3), g(hhageych) 
	mvencode hhageych, mv(0) 
	la var hhageych "age of youngest child in hh"
	la def hhageych 0 "no children" 1 "baby/toddler" 2 "young child" ///
		3 "yth q'naire age", modify 
	la val hhageych hhageych

	la var hhneti_adj2 "Monthly Household Net Income (£000s)" 
	la var nchild_dv "No. of Own Children in the Household"
	la var npens_dv "No. of Pensioners in the Household"

	/* HH Characteristics */ 
	n fre tenure_dv
	recode tenure_dv (1 2 = 1) (3/7 = 2) (8 = 3), g(tenure)
	la var tenure "housing tenure" 
	la def tenure ///
		1 "Owned" ///
		2 "Rented" ///
		3 "Other", modify
	la val tenure tenure 
	n fre tenure 

	g homeown = (tenure==1) if !mi(tenure)
	la var homeown "Own Home" 
	ta homeown tenure, m

	la var hhsize "Household Size"

	/* Geographic */
	ren gor_dv gor // last known gor 
	ren ba_gor_dv gor_w1 // gor at wave 1
	n fre gor_w1 gor 
	la var gor "Government office region"
	la var gor_w1 "Government office region at W1"
	foreach v in gor_w1 gor { 
		la def `v' 1 "North East England" 2 "North West England" ///
			3 "Yorkshire and the Humber" 4 "East Midlands" ///
			5 "West Midlands" 6 "East of England" 7 "London" ///
			8 "South East England" 9 "South West England" 10 "Wales" ///
			11 "Scotland" 12 "Northern Ireland" 13 "Channel Islands", modify 
		la val `v' `v'
	}

	n fre distmov2
	ta total_ivfio distmov2 
	g distmov3 = distmov2/total_ivfio // indexed by total number of interviews 
	ren distmov3 distmov 
	la var distmov "No. of Reported Moves"

	/* Survey */
	n fre month19 
	n fre w19 w2? if month19==-9
	n li w* if month19==-9 & w25==1 // 1 person who dropped out in w13, then came back in w23 - likely joined a UKHLS household so ignore discrepancy 
	recode month19 (-9 = 0), g(ukhls_month) 
	la var ukhls_month "Month of sample issue into UKHLS W2"
	mvencode ukhls_month, mv(0) o
	loc n = 0 
	foreach m in jan feb mar apr may jun jul aug sep oct nov dec { 
		loc n = `n'+1 
		la def ukhls_month `n' "`m' year 1", modify 
	}
	la def ukhls_month 0 "not issued to ukhls", modify
	la val ukhls_month ukhls_month
	n fre ukhls_month 

	save "$wdata\temp3", replace
}

/*====================================================================
                        4: Keep and Save  
====================================================================*/
qui {
	use "$wdata\temp3", clear

	loc vars clu* loyal lwint month* quarter w? w?? total_ivfio ivfio* ///
		wtranselig eligstat elig* ///
		female age agegrp* ethnmin partner hiqual job job2 ghq genhealth ///
		polint polparsup orgm2 ///
		hhageych hhneti_adj2 nchild_dv npens_dv ///
		dwelling tenure homeown hhsize ///
		gor gor_w1 distmov *indin91_lw ///
		
	cls
	n fre `vars'

	keep pidp `vars'
	save "$datasets\bhps_data2.dta", replace
}
/*====================================================================
                        Program Close
====================================================================*/
cap log close
forval i = 1/3 { 
	erase "$wdata\temp`i'.dta"
}