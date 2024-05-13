/*====================================================================
Understanding Participation in a Long-Term Household Panel Study: 
Evidence from the UK 
PhD Thesis

Nicole D James 
----------------------------------------------------------------------
Chapter:			1
Do File:			00_master.do 
Task: 				Set globals
----------------------------------------------------------------------
Creation Date:		13 Jan 2020
Do-file version:	01

User commands:		fre, isvar
====================================================================*/
/* 
Process Order: 

00_master.do 			set globals 
01_data_management_1.do		compile sample 
lgf_1_definition.lgf 		run unweighted LCA
01_data_management_2.do		prep covariates
01_data_management_3.do		generate eligibility weights
lgf_ue_definition.lgf		run weighted LCA
01_data_management_4.do 	merge LCA data and calculate weights
02_data_analysis_1.do 		produce graphs
02_data_analysis_2.do 		mn regression (DV - class assignment)
02_data_analysis_3.do 		mn regression (DV - reason for NR)

*/

/*====================================================================
                        0: Program set up
====================================================================*/
qui {
	clear all 
	macro drop _all
	set varabbrev off, permanently 
	set mat 11000

	/* Write Directory */
	glo dir "M:\PhD Survey Methodology\Paper 1"
	cd "$dir"

	/* Read Directory (UKHLS main survey data) */ 
	glo ukhlsdata " " 

	/* Wave Set-up */
	glo wn1 9 // latest ukhls wave
	glo syear = (2010+$wn1) // latest ukhls survey year
	glo wn1c = (18 + $wn1)-1 // bhps 18 waves + latest ukhls wave - ukhls w1 

	foreach x in dofiles datasets logfiles { 
		cap mkdir "$dir\stata/`x'"
		glo `x' "$dir\stata/`x'" 
	}
	foreach x in input output wdata { 
		cap mkdir "$datasets/`x'" 
		glo `x' "$datasets/`x'" 
	}

	glo latent_gold "$dir\latent_gold"
	foreach x in results syntax { 
		cap mkdir "$latent_gold/`x'"
		glo `x' "$latent_gold/`x'"
	}

	macro drop ukrevlist1 bhrevlist1 ukrevlist2 bhrevlist2 revlist
	forval i = 2/$wn1 { 
		loc w = substr("abcdefghijklmnopqr", `i',1)
		glo ukrevlist1 `w' ${ukrevlist1}
		glo ukrevlist2 `i' ${ukrevlist2}
		n di "${ukrevlist1}" _n "${ukrevlist2}"
	}
	forval i = 1/18 { 
		loc w = "b" + substr("abcdefghijklmnopqr", `i',1)
		glo bhrevlist1 `w' ${bhrevlist1}
		glo bhrevlist2 `i' ${bhrevlist2}
		n di "${bhrevlist1}" _n "${bhrevlist2}"
	}
	forval i = 1/$wn1c { 
		if inrange(`i',1,18) loc w = "b" + substr("abcdefghijklmnopqr", `i',1)
		else { 
			loc j = `i'-17
			loc w = substr("abcdefghijklmnopqr", `j',1)
		}
		glo revlist1 `w' ${revlist1}
		glo revlist2 `i' ${revlist2}
		n di "${revlist1}" _n "${revlist2}"
	}
	n macro list 
}

/*====================================================================
                        1: MN Regression Set Up
====================================================================*/
qui {
	* Put Covariates into globals 
	glo socdem female ib1.agegrp7 ethnmin partner ib0.hiqual ib1.job2 ///
		ib5.genhealth
	glo comatt ib4.polint polparsup 
	glo hhcomp c.hhneti_adj2 c.nchild_dv c.npens_dv
	glo hhcha ib1.dwelling homeown c.hhsize 
	glo geo  c.distmov

	glo cov $socdem $comatt $hhcomp $hhcha $geo
}
