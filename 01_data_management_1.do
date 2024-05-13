/*====================================================================
Understanding Participation in a Long-Term Household Panel Study: 
Evidence from the UK 
PhD Thesis

Nicole D James 
----------------------------------------------------------------------
Chapter:			1
Do File:			01_data_management_1.do 
Task: 				Compile Sample (before LCA)
----------------------------------------------------------------------
Creation Date:		13 Jan 2020
Modification Date: 	19 Mar 2021
Do-file version:    	02
====================================================================*/

cap log close 
log using "$logfiles\01_data_management_1.do", replace t 

/*====================================================================
                        1: BHPS Xwaveid
====================================================================*/
qui {
	use "$ukhlsdata\xwaveid_bh.dta", clear
	/* Stable characteristics */
	isvar pidp birthy sampst hhorig memorig ?wenum_dv_bh ///
		?wintvd_dv_bh *_hidp *_ivfio* *_ivfho* 
	cap keep `r(varlist)' 
	n cou // 43,272

	/* ------------------------------------------------------ */
	/* Validity Check:  Check BW1 outcome and First wave int. */
	n ta fwintvd_dv_bh ba_ivfio1_bh if fwintvd_dv_bh==1
	n ta fwintvd_dv_bh ba_ivfio1_bh if inrange(ba_ivfio1_bh,1,2) 
	/* ------------------------------------------------------ */

	n cou if fwintvd_dv_bh==1 // 10,264
	keep if fwintvd_dv_bh==1

	/* ------------------------------------------------------ */
	/* Validity Check: Check all OSM bhps gb (original) 1991 sample */
	n fre sampst hhorig memorig 
	/* ------------------------------------------------------ */

	isvar sampst hhorig memorig fwenum_dv_bh fwintvd_dv_bh
	cap drop `r(varlist)'

	ren ba_ivfio1_bh ivfio1
	ren ba_ivfho ivfho1
	ren ba_hidp hidp1

	n fre ivfio1
	keep if ivfio1==1 // 9,912 (excl. Proxy interviews)

	/* Flags for total outcome */
	g total_ivfio = (ivfio1==1)
	g total_ivfho = (ivfho1==10)
	clonevar full_ind_int1 = total_ivfio
	clonevar full_hh_int1 = total_ivfho 

	forval i = 2/18 { 
		loc w = "b" + substr("abcdefghijklmnopqr", `i',1) + "_"
		foreach x in hidp ivfio ivfho {
			ren `w'`x' `x'`i'
		}
		la var ivfio`i' "BHPS W`i' Individual Interview Outcome"
		la var ivfho`i' "BHPS W`i' Household Interview Outcome"
		replace total_ivfio=total_ivfio+1 if ivfio`i'==1 // full interview
		replace total_ivfho=total_ivfho+1 if ivfho`i'==10 // all eligible hh int
		g full_ind_int`i'=(ivfio`i'==1)
		g full_hh_int`i'=(ivfho`i'==10)
	}

	isvar b*_ivfho_bh 
	cap drop `r(varlist)'

	save "$wdata\bhps_merged_xwaveid", replace
}

/*====================================================================
                        2: UKHLS Xwaveid
====================================================================*/
qui {
	use "$ukhlsdata\xwaveid.dta", clear
	isvar pidp quarter ?_hidp ?_ivf?o ?_month 
	cap keep `r(varlist)' 
	tempfile xwaveid 
	save `xwaveid' 

	use "$wdata\bhps_merged_xwaveid", clear 
	merge 1:1 pidp using `xwaveid', keep(1 3) 

	/* ------------------------------------------------------ */
	/* Validity Check: BHPS sample not elgiible in UKHLS w1 
	should be missing for a_ivfio and a_ivfho */
	n fre a_ivfio a_ivfho
	/* ------------------------------------------------------ */

	forval i = 2/$wn1 { 
		loc w = substr("abcdefghijklmnopqrstuvwxyz", `i',1) + "_"
		loc j = 18+`i'-1 // ignore UKHLS w1
		foreach x in hidp ivfio ivfho month {
			ren `w'`x' `x'`j'
		}
		la var ivfio`j' "UKHLS W`i' Individual Interview Outcome"
		la var ivfho`j' "UKHLS W`i' Household Interview Outcome"	
		replace total_ivfio=total_ivfio+1 if ivfio`j'==1 & _merge==3 // full interview
		replace total_ivfho=total_ivfho+1 if ivfho`j'==10 & _merge==3 // all eligible hh int
		g full_ind_int`j'=(ivfio`j'==1)
		g full_hh_int`j'=(ivfho`j'==10)
	}

	isvar _merge a_*
	cap drop `r(varlist)' 
	save "$wdata\merged_xwaveid_wide", replace
}

/*====================================================================
                        3: Merged Xwaveid
====================================================================*/
qui {
	/* Convert to long format */
	use "$wdata\merged_xwaveid_wide", clear 
	reshape long full_ind_int full_hh_int hidp ivfho ivfio month , i(pidp) j(wave) 
	la var full_ind_int "Individual Interview (Ivfio==1) [Dummy]"
	la var full_hh_int "Household Interview (Ivfho==10) [Dummy]"
	save "$wdata\merged_xwaveid_long", replace

	/* Generate flags */
	use "$wdata\merged_xwaveid_wide", clear
	g total_bhps=0 // flag for total number of bhps interviews
	forval i = 1/18 { 
		replace total_bhps=total_bhps+1 if full_ind_int`i'==1
		ren full_ind_int`i' w`i'
	}
	forval i = 19/$wn1c { 
		ren full_ind_int`i' w`i'
	}
	
	forval i = 1/$wn1c { 
		g wave`i'= w`i'
	}
	save "$wdata\merged_xwaveid_wide2", replace
}

/*====================================================================
                        4: Generate Eligibility Variables
====================================================================*/
qui {
	use "$wdata\merged_xwaveid_wide2", clear 
	g wtranselig = . 	
	forval i = 1/$wn1c { 
		loc h = `i'-1 // t-1
		loc j = `i'+1 // t+1
		recode ivfio`i' ///
			(-9/-1 . = -9) ///
			(54/55 74 80 84 99 = 2) ///
			(12 18 32 52/53 63 82/83 98 = 3) /// 
			(else =  1), gen(elig`i')
			la var elig`i' "Eligibility Status in W`i'"
			la def elig`i' 1 "Eligible" 2 "Ineligible" 3 "Unknown Eligibility"
			la val elig`i' elig`i'
			
			if `i'!=1 {
				replace elig`i'=2 if elig`h'==2 & inlist(elig`i',-9,3) // ineligible if pw ineligible/miss
				replace elig`i'=3 if elig`h'==3 & inlist(elig`i',-9) // ineligible if pw ineligible/miss
				replace elig`i'=3 if elig`i'==-9 & ivfio`h'==81 // pw ad refusal eligible at wave refused then UE thereafter
				replace elig`i'=3 if inlist(elig`h',1,3) & elig`i'==-9 // UE
			
			}
	}
	clonevar eligstat = elig26
	la var eligstat "Last observed elgiibility status"	
	
	g chk_elig=. 
	foreach i of glo revlist2 {
		loc h = `i'-1 // t-1
		loc j = `i'+1 // t+1
		if `i'!=1 {
			replace elig`h'=1 if elig`i'==1 & inlist(elig`h',-9,2,3)
		}	
		cap replace wtranselig = `i' if elig26==2 & inlist(elig`i',1,3) & elig`j'==2 & mi(wtranselig)
		cap replace wtranselig = `i' if elig26==3 & inlist(elig`i',1,2) & elig`j'==3 & mi(wtranselig)
		
		replace chk_elig = `i' if mi(chk_elig) & elig`i'==1 
	}
	replace wtranselig = wtranselig+1 if !mi(wtranselig)
	
	/* Export Data for LCA in Latent Gold */
	preserve 
		order pidp total_ivfio w? w?? wave* elig* 
		keep pidp w* total_ivfio wtranselig eligstat elig* chk_elig
		g total_1 = 0 
		g total_m = 0 
		forval i = 1/$wn1c { 
			replace w`i'=. if (w`i'==0) & elig`i'==2 
			replace total_1 = total_1 + 1 if w`i'==1 
			replace total_m = total_m + 1 if w`i'==. 
		}
		n fre total* 
		/* people who are "loyal" includes people who have responded at 
		every wave as well as those who responded at every wave up to
		becoming ineligible */ 
		g total = total_1 + total_m 
		cap drop loyal 
		g loyal = (total==$wn1c)
		n fre loyal
		
		keep pidp w* loyal wtranselig
		drop wave* 
		save "$datasets\lca_bhps_harmonised.dta", replace
		/* CSV file to be used for LCA */
		export delim "$datasets\lca_bhps_harmonised.csv", replace nolabel
	restore 

	keep pidp wtranselig eligstat elig* chk_elig
	n save "$wdata\wtranselig", replace
}

/*====================================================================
                        5: Merge Wave-Specific Files
====================================================================*/
qui {
	use "$wdata\merged_xwaveid_wide2", clear
	merge 1:1 pidp using "$wdata\wtranselig.dta", keep(1 3) nogen
	forval i =1/$wn1c { 
		drop w`i'
	}
	merge 1:1 pidp using "$datasets\lca_bhps_harmonised.dta", keep(1 3) keepus(w* loyal)
	merge 1:1 pidp using "$ukhlsdata\xwavedat.dta", keep(1 3) nogen ///
		keepus(quarter sex sex_dv ukborn plbornc bornuk_dv ethn_dv plbornd)

	/* Merge BHPS Wave-Specific Files */
	forval i = 1/18 { 
		loc w = "b" + substr("abcdefghijklmnopqr", `i',1) + "_"
		
		/* indall*/
		merge 1:1 pidp using "$ukhlsdata/`w'indall", keep(1 3) nogen ///
			keepus(`w'age `w'mastat `w'nchild_dv)
		ren `w'age `w'age_dv // rename so in line with UKHLS
		if `i'!=1 merge 1:1 pidp using "$ukhlsdata/`w'indall", keep(1 3) nogen ///
			keepus(`w'distmov) // not avail. in bw1 
		
		/* indresp*/
		merge 1:1 pidp using "$ukhlsdata/`w'indresp", keep(1 3) nogen ///
			keepus(`w'hiqual_dv `w'scghq1_dv `w'fimnlabgrs_dv `w'fimngrs_dv ///
			`w'jbstat `w'istrtdatm `w'vote1)
		if !inlist(`i',9,14) merge 1:1 pidp using "$ukhlsdata/`w'indresp", ///
			keep(1 3) nogen keepus(`w'hlstat) // not avail. in bw9, bw14
		if inlist(`i',9,14) merge 1:1 pidp using "$ukhlsdata/`w'indresp", ///
			keep(1 3) nogen keepus(`w'hlsf1) // only avail. in bw9, bw14
		if inrange(`i',2,18) merge 1:1 pidp using "$ukhlsdata/`w'indresp", ///
			keep(1 3) nogen keepus(`w'istrtdaty) // not avail. in bw1 
		if inrange(`i',1,5) | inlist(`i',7,9,11,13,15,17) merge 1:1 pidp using ///
			"$ukhlsdata/`w'indresp", keep(1 3) nogen keepus(`w'orgm*) 
			// only avail. in bw1-5, 7,9,11,13,15,17
		if inrange(`i',1,6) | inrange(`i',11,18) merge 1:1 pidp using ///
			"$ukhlsdata/`w'indresp", keep(1 3) nogen keepus(`w'vote6) 
			// only avail. in bw1-6, bw11-18
	
		/* HH level files */ 
		preserve 
			foreach hhf in hhresp hhsamp {
				use "$ukhlsdata/`w'`hhf'", clear
				ren `w'hidp hidp`i'
				tempfile `hhf'`i' 
				save ``hhf'`i''
			}
		restore
		
		/* hhresp */ 
		merge m:1 hidp`i' using `hhresp`i'', keep(1 3) nogen ///
			keepus(`w'hsownd_bh `w'nkids_dv `w'hhsize `w'tenure_dv ///
			`w'hstype `w'agechy_dv `w'fihhmngrs_dv `w'hhneti `w'nch02_dv ///
			`w'npens_dv `w'eq_moecd `w'intdatem)
		if `i'!=1 merge m:1 hidp`i' using `hhresp`i'', keep(1 3) nogen ///
			keepus(`w'intdatey) // not avail. in bw1
			
		/* hhsamp */ 
		merge m:1 hidp`i' using `hhsamp`i'', keep(1 3) nogen /// 
			keepus(`w'gor_dv) 
	}

	/* Merge UKHLS Wave-Specific Files */
	forval i = 2/$wn1 {
		loc w = substr("abcdefghijklmnopqrstuvwxyz", `i',1) + "_"
		
		/* indall */
		merge 1:1 pidp using "$ukhlsdata/`w'indall", keep(1 3) nogen ///
			keepus(`w'age_dv `w'urban_dv `w'marstat `w'nchild_dv)
			
		/* indresp */
		merge 1:1 pidp using "$ukhlsdata/`w'indresp", keep(1 3) nogen ///
			keepus(`w'hiqual_dv `w'scghq1_dv `w'fimnlabgrs_dv `w'fimngrs_dv ///
			`w'jbstat `w'health `w'istrtdaty `w'sf1 `w'scsf1 `w'istrtdatm ///
			`w'indin91_lw)
		if inrange(`i',3,$wn1) merge 1:1 pidp using "$ukhlsdata/`w'indresp", ///
			keep(1 3) nogen keepus(`w'distmov_dv) // not avail. in w2
		if inlist(`i',3,6,9) merge 1:1 pidp using "$ukhlsdata/`w'indresp", ///
			keep(1 3) nogen keepus(`w'orgm*) // only avail. in bw1-5, 7,9,11,13,15,17
		if `i'!=8 merge 1:1 pidp using "$ukhlsdata/`w'indresp", ///
			keep(1 3) nogen keepus(`w'vote1 `w'vote6) // not avail in w8
			
		/* HH level files */ 
		preserve
			foreach hhf in hhresp hhsamp {
				use "$ukhlsdata/`w'`hhf'", clear
				loc j = 17+`i'
				ren `w'hidp hidp`j'
				tempfile `hhf'`j' 
				save ``hhf'`j''
			}
		restore
		
		/* hhresp */
		merge m:1 hidp`j' using `hhresp`j'', keep(1 3) nogen ///
			keepus(`w'hsownd `w'nkids_dv `w'hhsize `w'nemp_dv `w'tenure_dv ///
			`w'agechy_dv `w'fihhmngrs_dv `w'fihhmnnet3_dv `w'nch02_dv ///
			`w'npens_dv `w'ieqmoecd_dv `w'intdatem `w'intdatey)
		
		/* hhsamp */
		merge m:1 hidp`j' using `hhsamp`j'', keep(1 3) nogen /// 
			keepus(`w'gor_dv `w'country `w'dweltyp)
	}
	
	save "$datasets\merged.dta", replace 
}

/*====================================================================
                        Program Close
====================================================================*/
cap log close

loc del bhps_merged_xwaveid merged_xwaveid_wide merged_xwaveid_wide2 ///
	merged_xwaveid_long
foreach d of loc del { 
	erase "$wdata/`d'.dta"
}
