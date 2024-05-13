/*====================================================================
Understanding Participation in a Long-Term Household Panel Study: 
Evidence from the UK 
PhD Thesis

Nicole D James 
----------------------------------------------------------------------
Chapter:			1
Do File:			01_data_management_4.do 
Task: 				Merge LCA data and calculate weights
----------------------------------------------------------------------
Creation Date:		13 Jan 2020
Modification Date: 	19 Mar 2021
Do-file version:	02
====================================================================*/

cap log close 
log using "$logfiles\01_data_management_4.log", replace t 

/*====================================================================
                        1: Final Models
====================================================================*/
qui { 
	/* posterior probs */
	foreach x in 1 ue {
		import delim "$latent_gold\results\final_model_`x'.csv" , clear varnames(1)
		isvar pidp weight clu* 
		keep `r(varlist)'
		ren clu? clu_?
		ren clu* clu_`x'*
		if "`x'"=="ue" bys pidp(weight): g n = _n
		tempfile pp_`x'
		save `pp_`x''
	}
	
	/*unweighted (for UE) */
	n di as res _n(2) "Unweighted" _n
	use "$datasets\bhps_data2.dta", clear 
	drop clu*
	n cou // 9,912 individuals 
	merge 1:1 pidp using `pp_1', keep(1 3) nogen
	reshape long clu_1_, i(pidp) j(class)
	ren clu_1_ pp 
	la var pp "posterior probability" // used as weight to account for classification error 
	la var class "lca class"
	n cou // 89,208 records - 9 classes for 9,912 individuals 
	g weight = pp 
	la var weight "weight"
	by pidp: egen sum = total(weight)
	n fre sum 
	assert inrange(sum,0.99,1.01)
	drop sum
	save "$datasets\final_data_1.dta", replace 
	
	/*weighted (for UE) */
	n di as res _n(2) "Weighted" _n
	use "$datasets\bhps_data3.dta", clear 
	drop n 
	bys pidp(weight): g n = _n
	drop clu*
	n cou //14,696 records (9,912 individuals - UE have two records)
	ren weight weight_chk
	merge 1:1 pidp n using `pp_ue' 
	datacheck weight==weight_chk, flag nol
	cou if _contra==1 
	if `r(N)'!=434 error 9 
	drop weight_chk
	reshape long clu_ue_, i(pidp weight) j(class)
	ren clu_ue_ pp 
	ren weight ue_weight
	la var pp "posterior probability" // used as weight to account for classification error 
	la var class "lca class"
	la var ue_weight "unknown eligibility weight"
	g weight = ue_weight * pp 
	la var weight "weight"
	n cou // 102,872 records - 7 classes for 9,912 individuals (14,696 records)
	by pidp: egen sum = total(weight)
	n fre sum 
	assert inrange(sum,0.99,1.01)
	drop sum
	save "$datasets\final_data_ue.dta", replace
}

/*====================================================================
                        Program Close
====================================================================*/
cap log close 