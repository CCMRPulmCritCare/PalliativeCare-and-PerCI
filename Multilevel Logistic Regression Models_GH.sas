/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/**/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/
*
* Project: K23 Aim 3
*
* Author: Jennifer Cano
* Date Created: 4/12/24
*
* Description: Run analysis and create tables/figures for manuscript
*
/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/**/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/;

libname coh 'filepath';
libname manu 'filepath';


/*/*/*/*/*/* Create Table 1 */*/*/*/*/*/;

*create unique hosp data set;
data manu.uniqhosp_20240712;
set coh.k23_primarycoh_20240626; 
where new_ICU_day_bedsection = 1;
run;


*Continuous Vars;
ods excel file='filepath' 
options(sheet_name = "Continous Vars" sheet_interval='proc' absolute_column_width="12" ) ;
proc means data=manu.uniqhosp_20240712 maxdec=2 median p25 p75 stackodsoutput;
class perci;
var age_hosp elixhauser_vanwalraven va_risk_score_icu_perc icu_los hosp_los 
avg_operating_beds_oct2015_2021;
ways 0 1;
run;


*Categorical Vars;

*create new race var for table;
proc freq data=manu.uniqhosp_20240712;
tables race_new;
run;

data manu.uniqhosp_20240712;
set manu.uniqhosp_20240712;
if race_new not in ("BLACK OR AFRICAN AMERICAN" "WHITE") then race_table1 = "OTHER";
	else race_table1 = race_new;
run;

*create new in-hosp mortality var using dod_new - we want to include day after discharge as in-hosp;
data manu.uniqhosp_20240712;
set manu.uniqhosp_20240712 /*(drop=inhosp_mort_new)*/;
if new_admitdate3 <= dod_hosp <= new_dischargedate3+1 then inhosp_mort_new = 1;
	else inhosp_mort_new = 0;
run;

proc freq data=manu.uniqhosp_20240712;
tables (race_table1 gender inhosp_mort_new avg_fac_cmplx_fy17_20_round
psych_ICUadmit medsurg_ICUadmit new_teaching region)*perci  ;
run;


ods excel options(sheet_name = "Categorical Vars");
proc tabulate data=manu.uniqhosp_20240712 missing order=freq
format =8.1;
class  perci race_table1 gender inhosp_mort_new avg_fac_cmplx_fy17_20_round
psych_ICUadmit medsurg_ICUadmit new_teaching region;

table race_table1 gender inhosp_mort_new avg_fac_cmplx_fy17_20_round
psych_ICUadmit medsurg_ICUadmit new_teaching region
all ='Column Total',
all(colpctn) perci*(n colpctn) / nocellmerge;
run;
ods excel close;


*merge in discharge destination;
libname disch 'filepath';

proc sql;
create table Discharge365_VAPD20142021 as
select a.*, b.DischargePlus1, b.DischargePlus2 
from manu.uniqhosp_20240712 a
left join disch.Discharge365_20240626 b
	on a.unique_hosp_count_id = b.unique_hosp_count_id;
quit;

/*if DischargePlus = 0 then output dead;*/
/*if DischargePlus = 1 then output acute;*/
/*if DischargePlus = 3 then output non_acute;*/
/*if DischargePlus = 5 then output home;*/

proc freq data=Discharge365_VAPD20142021;
tables /*DischargePlus1 DischargePlus1*perci*/
DischargePlus2 DischargePlus2*perci /  norow;
run;

proc freq data=Discharge365_VAPD20142021;
tables DischargePlus2 DischargePlus2*perci /  norow;
where DischargePlus1 ne 0;
run;

*operating room variable;
libname or 'filepath';

proc sql;
create table oproom as
select distinct a.*, b.or_during_ICUday1or2, b.or_during_ICUday1or2_hosp, b.surgerydate
from coh.k23_primarycoh_20240626 a
left join or.or2015_2021_20240626 b
on a.unique_ICU_specialty=b.unique_ICU_specialty and a.datevalue=b.surgerydate;
quit;

data oproom;
set oproom;
if or_during_ICUday1or2_hosp = . then or_during_ICUday1or2_hosp = 0;
run;

proc freq data=oproom;
tables perci*or_during_ICUday1or2_hosp ;
where new_ICU_day_bedsection = 1 ;
run;


*Table 2 vars;

*first need to create hosp level vars of days ;

data pc;
set coh.k23_primarycoh_20240626;
run;

options macrogen symbolgen mlogic merror;

%macro days;

%do i = 4 %to 11;

proc sort data= pc;
by unique_hosp_count_id descending pallcare_ICUday&i;
run;

data pc;
set pc;
by unique_hosp_count_id;
retain pallcare_ICUday&i._hosp;
if first.unique_hosp_count_id then pallcare_ICUday&i._hosp = pallcare_ICUday&i;
run;

%end;
%mend;

%days

*merge new variables into analysis cohort;
proc print data=pc (obs=1);run;

proc sort data=pc out=pc2 nodupkey;
by unique_hosp_count_id;
run;

proc sql;
create table pc3 as
select distinct a.*, b.pallcare_ICUday4_hosp, b.pallcare_ICUday5_hosp , b.pallcare_ICUday6_hosp, 
			b.pallcare_ICUday7_hosp, b.pallcare_ICUday8_hosp, b.pallcare_ICUday9_hosp, 
			b.pallcare_ICUday10_hosp, b.pallcare_ICUday11_hosp 
from manu.uniqhosp_20240712 a
left join pc2 b
	on a.unique_hosp_count_id=b.unique_hosp_count_id;
quit;

data manu.uniqhosp_20240712;
set manu.uniqhosp_20240712;
drop pallcare_ICUday_new1_hosp--pallcare_ICUday_new11_hosp;
run;

*save;
data manu.uniqhosp_20240712;
set pc3;
run;

*create indicators for pall care days 1-3 vs 4-11;

data manu.uniqhosp_20240712;
set manu.uniqhosp_20240712 (drop=pallcare_days);
length pallcare_days $9.;
if (pallcare_ICUday1_hosp= 1 or pallcare_ICUday2_hosp = 1 or pallcare_ICUday3_hosp =1) 
	then pallcare_days = "Days 1-3";
		else if (pallcare_ICUday4_hosp = 1 or pallcare_ICUday5_hosp = 1 or pallcare_ICUday6_hosp = 1 or pallcare_ICUday7_hosp = 1 or
			pallcare_ICUday8_hosp = 1 or pallcare_ICUday9_hosp = 1 or pallcare_ICUday10_hosp = 1 or pallcare_ICUday11_hosp = 1)
				and (pallcare_ICUday1_hosp= 0 or pallcare_ICUday2_hosp = 0 or pallcare_ICUday3_hosp =0)
					then pallcare_days = "Days 4-11";
run;


*create early palliative care/hospice indicator (palliative care/hospice on first 3 ICUdays);
data manu.uniqhosp_20240712;
set manu.uniqhosp_20240712 (drop=/*pallcare_days_new_1_3*/ pallcare_days_1_3);
if (pallcare_ICUday1_hosp= 1 or pallcare_ICUday2_hosp = 1 or pallcare_ICUday3_hosp =1)
	then pallcare_days_1_3 = 1;
	else pallcare_days_1_3 = 0;
run;



/*/*/*/*/*/*/*/*  Analysis 2: Quantifying variation in PerCI across facilities  */*/*/*/*/*/*/*/;

proc freq data = manu.uniqhosp_20240712 nlevels;
tables gender 
htn_hosp  chf_hosp  cardic_arrhym_hosp  valvular_d2_hosp  pulm_circ_hosp  pvd_hosp  paralysis_hosp  neuro_hosp  pulm_hosp  dm_uncomp_hosp  dm_comp_hosp  
hypothyroid_hosp  renal_hosp  liver_hosp pud_hosp  ah_hosp  lymphoma_hosp  cancer_met_hosp  cancer_nonmet_hosp  ra_hosp  coag_hosp  obesity_hosp  wtloss_hosp  
fen_hosp  anemia_cbl_hosp  anemia_def_hosp  etoh_hosp  drug_hosp  psychoses_hosp  depression_hosp primarydx_ICUadmit 
new_teaching medsurg_ICUadmit psych_ICUadmit;
run;

proc means data = manu.uniqhosp_20240712 nmiss median;
var age va_risk_score_icu_perc avg_iculevel_fy14_fy23 avg_operating_beds_oct2015_2021;
run;

*recode comorbidities so that missing is = to 0;
%let list = htn_hosp  chf_hosp  cardic_arrhym_hosp  valvular_d2_hosp  pulm_circ_hosp  pvd_hosp  paralysis_hosp  neuro_hosp  pulm_hosp  dm_uncomp_hosp  dm_comp_hosp  
hypothyroid_hosp  renal_hosp  liver_hosp pud_hosp  ah_hosp  lymphoma_hosp  cancer_met_hosp  cancer_nonmet_hosp  ra_hosp  coag_hosp  obesity_hosp  wtloss_hosp  
fen_hosp  anemia_cbl_hosp  anemia_def_hosp  etoh_hosp  drug_hosp  psychoses_hosp  depression_hosp ;

%macro recode;
data manu.uniqhosp_20240712;
set manu.uniqhosp_20240712;

%do i=1 %to %sysfunc(countw(&list,' ',q));
	%let next1 = %scan(&list,&i,' ',q);

		if &next1 = . then &next1 = 0;
%end;
run;
%mend recode;

%recode

*import ICD-10 CCSR categories;
options validvarname=v7;

proc import datafile="filepath"
out=icd10ccsr
dbms= csv replace;
guessingrows=max;
run;

proc sql;
create table dx_10 as
select distinct a.*, c.CCSR_CATEGORY_1_DESCRIPTION as CCSR_CATEGORY format = $500.
from manu.uniqhosp_20240712 a
left join icd10ccsr c
	on compress(a.primarydx_ICUadmit,".") = c.ICD_10_CM_CODE;
quit;

proc sql;
select count (distinct unique_hosp_count_id)
from dx_10;
quit;

*save;
data manu.uniqhosp_20240712;
set dx_10;
run;

*what are the top 20 categories?;
proc sort data=manu.uniqhosp_20240712 nodupkey out=top20;
by unique_hosp_count_id CCSR_CATEGORY;
run;

proc freq data= top20 order=freq nlevels;
tables CCSR_CATEGORY;
run;

*create top 20 dicohotomous ccsr categories to put in logistic regression models
instead of using primary diagnosis variable;
data manu.uniqhosp_20240712;
set manu.uniqhosp_20240712;
if CCSR_CATEGORY = 'Septicemia' then ccsr_septicemia = 1; else ccsr_septicemia = 0;
if CCSR_CATEGORY = 'Coronary atherosclerosis and other heart disease' then ccsr_cor_atherosc = 1; else ccsr_cor_atherosc = 0;
if CCSR_CATEGORY = 'Respiratory failure; insufficiency; arrest' then ccsr_respfail = 1; else ccsr_respfail = 0;
if CCSR_CATEGORY = 'Acute myocardial infarction' then ccsr_acute_myocard_infarc = 1; else ccsr_acute_myocard_infarc = 0;
if CCSR_CATEGORY = 'Cardiac dysrhythmias' then ccsr_cardiac_dysrhyth = 1; else ccsr_cardiac_dysrhyth = 0;
if CCSR_CATEGORY = 'Hypertension with complications and secondary hypertension' then ccsr_htn_w_compl = 1; else ccsr_htn_w_compl = 0;
if CCSR_CATEGORY = 'Peripheral and visceral vascular disease' then ccsr_periph_visc_vasc_dis = 1; else ccsr_periph_visc_vasc_dis = 0;
if CCSR_CATEGORY = 'Diabetes mellitus with complication' then ccsr_dm_w_compl = 1; else ccsr_dm_w_compl = 0;
if CCSR_CATEGORY = 'Heart failure' then ccsr_heart_fail = 1; else ccsr_heart_fail = 0;
if CCSR_CATEGORY = 'Aortic; peripheral; and visceral artery aneurysms' then ccsr_artery_aneurysm = 1; else ccsr_artery_aneurysm = 0;
if CCSR_CATEGORY = 'Respiratory cancers' then ccsr_resp_cancer = 1; else ccsr_resp_cancer = 0;
if CCSR_CATEGORY = 'Nonrheumatic and unspecified valve disorders' then ccsr_unspec_valve_disord = 1; else ccsr_unspec_valve_disord = 0;
if CCSR_CATEGORY = 'Gastrointestinal hemorrhage' then ccsr_gastro_hemorrhage = 1; else ccsr_gastro_hemorrhage = 0;
if CCSR_CATEGORY = 'Spondylopathies/spondyloarthropathy (including infective)' then ccsr_spondylo = 1; else ccsr_spondylo = 0;
if CCSR_CATEGORY = 'Occlusion or stenosis of precerebral or cerebral arteries without infarction' then ccsr_occl_stenosis_cerebr_art = 1; else ccsr_occl_stenosis_cerebr_art = 0;
if CCSR_CATEGORY = 'Alcohol-related disorders' then ccsr_alcohol_disord = 1; else ccsr_alcohol_disord = 0;
if CCSR_CATEGORY = 'Chronic obstructive pulmonary disease and bronchiectasis' then ccsr_cor_atherosc = 1; else ccsr_cor_atherosc = 0;
if CCSR_CATEGORY = 'Complication of cardiovascular device, implant or graft, initial encounter' then ccsr_complic_cardio_device = 1; else ccsr_complic_cardio_device = 0;
if CCSR_CATEGORY = 'COVID-19' then ccsr_covid = 1; else ccsr_covid = 0;
if CCSR_CATEGORY = 'Fluid and electrolyte disorders' then ccsr_fluid_electr_disord = 1; else ccsr_fluid_electr_disord = 0;
run;

proc freq data=manu.uniqhosp_20240712;
tables ccsr_septicemia--ccsr_fluid_electr_disord;
run;


/*Model 1: unadjusted event rates--empty model with no fixed intercept.*/
%macro doestsint;
%do hosp=1 %to 104;
estimate "&hosp." int 1 
  |intercept 1/subject %do k=1 %to %eval(&hosp.-1); 0 %end; 1 ilink e cl;
%end;
%mend;

ods output solutionr=manu.randomeffect1_20240626 CovParms=manu.cov1_20240626 estimates=manu.est_meanpop_int_20240626;
proc glimmix data=manu.uniqhosp_20240712 method=quad;
class sta6a ;
model perci(event='1')=  / /*noint*/ link=logit dist=binary solution cl ddfm=bw oddsratio(label) ;
random intercept/sub=sta6a solution cl  ;
%doestsint;
run;
ods output close;

/*Calculate the Median Odds Ratio (see Merlo, 2005) and ICC*/
data manu.cov1_20240626;
set manu.cov1_20240626;
lowerci=estimate-1.96*stderr;
upperci=estimate+1.96*stderr;
mor=exp(0.6745*sqrt(2*estimate));
mor_l=exp(0.6745*sqrt(2*lowerci));
mor_u=exp(0.6745*sqrt(2*upperci));
icc = estimate/(estimate+3.29);
run;

*Prepare data for caterpillar plot;
proc sort data=manu.est_meanpop_int_20240626; by estimate; run;

data manu.est_meanpop_int_20240626;
set manu.est_meanpop_int_20240626;
hosp=_n_;
run;

*caterpillar plot;
proc sgplot data=manu.est_meanpop_int_20240626;
scatter x=hosp y=mu/legendlabel="Unadjusted Event Rate" jitter;
highlow x=hosp low=lowermu high=uppermu/legendlabel="95% CI";
yaxis label="Event Rate" values=(0 to 0.15 by 0.05);
xaxis display=none;
run;


/*Model 2: Adjusted event rates - patient characteristics*/

*1. Calculate population means of all patient-level covariates (each categorical variable must be coded as indicator variables);
proc freq data=manu.uniqhosp_20240712;
tables gender ;
run;

data manu.uniqhosp_20240712;
set manu.uniqhosp_20240712;
if gender = "M" then male = 1;
	else male = 0;

run;

proc means data=manu.uniqhosp_20240712 mean stackods ;
var age male ccsr_septicemia ccsr_cor_atherosc ccsr_respfail ccsr_acute_myocard_infarc ccsr_cardiac_dysrhyth ccsr_htn_w_compl 
	ccsr_periph_visc_vasc_dis ccsr_dm_w_compl ccsr_heart_fail ccsr_artery_aneurysm ccsr_resp_cancer ccsr_unspec_valve_disord 
	ccsr_gastro_hemorrhage ccsr_spondylo ccsr_occl_stenosis_cerebr_art ccsr_alcohol_disord ccsr_complic_cardio_device 
	ccsr_covid ccsr_fluid_electr_disord va_risk_score_icu_perc htn_hosp  chf_hosp  cardic_arrhym_hosp  valvular_d2_hosp  
	pulm_circ_hosp  pvd_hosp  paralysis_hosp  neuro_hosp  pulm_hosp  dm_uncomp_hosp  dm_comp_hosp  
	hypothyroid_hosp  renal_hosp  liver_hosp pud_hosp  ah_hosp  lymphoma_hosp  cancer_met_hosp  cancer_nonmet_hosp  ra_hosp  
	coag_hosp  obesity_hosp  wtloss_hosp fen_hosp  anemia_cbl_hosp  anemia_def_hosp  etoh_hosp  drug_hosp  psychoses_hosp  depression_hosp;
ods output summary=means (drop=label);
run;

proc print data=means noobs;
run;

*2. Fit an adjusted model;

%macro doests;
%do hosp=1 %to 104;
estimate "&hosp." int 1 age 67.492846 
male 0.956033 
ccsr_septicemia 0.079932 
ccsr_cor_atherosc 0.017655 
ccsr_respfail 0.054186 
ccsr_acute_myocard_infarc 0.042178 
ccsr_cardiac_dysrhyth 0.047910 
ccsr_htn_w_compl 0.037702 
ccsr_periph_visc_vasc_dis 0.025199 
ccsr_dm_w_compl 0.027796 
ccsr_heart_fail 0.024763 
ccsr_artery_aneurysm 0.022409 
ccsr_resp_cancer 0.021663 
ccsr_unspec_valve_disord 0.017432 
ccsr_gastro_hemorrhage 0.020718 
ccsr_spondylo 0.016702 
ccsr_occl_stenosis_cerebr_art 0.018444 
ccsr_alcohol_disord 0.020699 
ccsr_complic_cardio_device 0.013047 
ccsr_covid 0.013206 
ccsr_fluid_electr_disord 0.011846 
va_risk_score_icu_perc 10.302661 
htn_hosp 0.720270 
chf_hosp 0.299073 
cardic_arrhym_hosp 0.389921 
valvular_d2_hosp 0.097261 
pulm_circ_hosp 0.075980 
pvd_hosp 0.181098 
paralysis_hosp 0.007913 
neuro_hosp 0.112589 
pulm_hosp 0.310518 
dm_uncomp_hosp 0.218388 
dm_comp_hosp 0.221051 
hypothyroid_hosp 0.099146 
renal_hosp 0.269050 
liver_hosp 0.114197 
pud_hosp 0.014213 
ah_hosp 0.008193 
lymphoma_hosp 0.015226 
cancer_met_hosp 0.043213 
cancer_nonmet_hosp 0.143918 
ra_hosp 0.019250 
coag_hosp 0.093897 
obesity_hosp 0.129401 
wtloss_hosp 0.089911 
fen_hosp 0.347835 
anemia_cbl_hosp 0.016370 
anemia_def_hosp 0.070009 
etoh_hosp 0.127893 
drug_hosp 0.058018 
psychoses_hosp 0.028706 
depression_hosp 0.163758 
 |intercept 1/subject %do k=1 %to %eval(&hosp.-1); 0 %end; 1 ilink e cl;
%end;
%mend;

ods output solutionr=manu.randomeffect2_20240626 parameterestimates=manu.parameterestimates2_20240626
				CovParms=manu.cov2_20240626 estimates=manu.estimates_meanpop_20240626;
proc glimmix data=manu.uniqhosp_20240712 method=laplace;
class sta6a  ;
model perci(event='1')=age male ccsr_septicemia ccsr_cor_atherosc ccsr_respfail ccsr_acute_myocard_infarc ccsr_cardiac_dysrhyth ccsr_htn_w_compl 
	ccsr_periph_visc_vasc_dis ccsr_dm_w_compl ccsr_heart_fail ccsr_artery_aneurysm ccsr_resp_cancer ccsr_unspec_valve_disord 
	ccsr_gastro_hemorrhage ccsr_spondylo ccsr_occl_stenosis_cerebr_art ccsr_alcohol_disord ccsr_complic_cardio_device 
	ccsr_covid ccsr_fluid_electr_disord va_risk_score_icu_perc htn_hosp  chf_hosp  cardic_arrhym_hosp  valvular_d2_hosp  
	pulm_circ_hosp  pvd_hosp  paralysis_hosp  neuro_hosp  pulm_hosp  dm_uncomp_hosp  dm_comp_hosp  
	hypothyroid_hosp  renal_hosp  liver_hosp pud_hosp  ah_hosp  lymphoma_hosp  cancer_met_hosp  cancer_nonmet_hosp  ra_hosp  
	coag_hosp  obesity_hosp  wtloss_hosp fen_hosp  anemia_cbl_hosp  anemia_def_hosp  etoh_hosp  drug_hosp  psychoses_hosp  depression_hosp
 / link=logit dist=binary solution cl ddfm=bw;
random intercept/sub=sta6a solution cl  ;
%doests;
run;
ods output close;

/*Calculate the Median Odds Ratio (see Merlo, 2005)*/
data manu.cov2_20240626;
set manu.cov2_20240626;
lowerci=estimate-1.96*stderr;
upperci=estimate+1.96*stderr;
mor=exp(0.6745*sqrt(2*estimate));
mor_l=exp(0.6745*sqrt(2*lowerci));
mor_u=exp(0.6745*sqrt(2*upperci));
icc = estimate/(estimate+3.29);
run;

*Prepare data for caterpillar plot;
proc sort data=manu.estimates_meanpop_20240626; by estimate; run;

data manu.estimates_meanpop_20240626;
set manu.estimates_meanpop_20240626;
hosp=_n_;
run;

*Figure 1: caterpillar plot;
proc sgplot data=manu.estimates_meanpop_20240626;
scatter x=hosp y=mu/legendlabel="Adjusted Event Rate" jitter;
highlow x=hosp low=lowermu high=uppermu/legendlabel="95% CI";
yaxis label="Probability of persistent critical illness" values=(0 to 0.15 by 0.05)
		labelattrs=(size=14) valueattrs=(size=14);
xaxis label="Hospitals" labelattrs=(size=14) valueattrs=(size=14);
keylegend /  valueattrs=(size=14);
run;

*create quintile rank variable to then merge with cohort for rest of analysis ;
proc rank data=manu.estimates_meanpop_20240626 out=quintile_m2 groups=5;
var mu;
ranks quintile;
run;

proc means data=quintile_m2 min max;
var mu;
class quintile;
run;

proc means data=manu.estimates_meanpop_20240626 min max;
var Statement;
run;

*sort sta6a's and assign id to match with quintile data set;
proc sort data=manu.uniqhosp_20240712 /*nodupkey out=facilities*/;
by sta6a;
run;

data manu.uniqhosp_20240712;
set manu.uniqhosp_20240712 (drop=facility_id);
by sta6a;
if first.sta6a then 
facility_id + 1;
run;

*merge quintile rank into cohort;
*7/11/24 need to create scatterplots using event rate (mu value);
*will need to merge in mu values into main data set;

proc sql;
create table hosp_quint as
select a.*, b.quintile as model2_quintile, b.mu as model2_mu, b.lowermu as model2_lowermu, b.uppermu as model2_uppermu
from manu.uniqhosp_20240712 /*(drop=model2_quintile)*/ a 
left join quintile_m2 b 
	on a.facility_id = b.statement;
quit;

*save;
data manu.uniqhosp_20240712;
set hosp_quint;
run;

proc sgplot data=manu.uniqhosp_20240712;
scatter x=sta6a y=mu/legendlabel="Adjusted Event Rate" /*jitter*/;
highlow x=sta6a low=lowermu high=uppermu/legendlabel="95% CI";
yaxis label="Event Rate" values=(0 to 0.15 by 0.05);
xaxis display=none;
run;


/*/*/* Model 2 Quintiles: Table 2 and Supplement appendix B Table 3 */*/*/;

*create ICU mortality variable;
data manu.uniqhosp_20240712;
set manu.uniqhosp_20240712 (drop=icu_mort);
if icu_admitdate <= dod_hosp <= icu_dischargedate then icu_mort = 1;
	else icu_mort=0;
run;

proc freq data = manu.uniqhosp_20240712;
tables (cvshock_ICU_newoccur_hosp respfail_ICU_newoccur_hosp
		renalfail_ICU_newoccur_hosp coagfail_ICU_newoccur_hosp
		liverfail_ICU_newoccur_hosp any_organ_fail pallcare_days_1_3
		pallcare_ICU_newoccur_hosp pallcare_anyICUday1_11_hosp icu_mort)*model2_quintile / nopercent /*norow nocol*/ ;
run;

proc freq data=manu.uniqhosp_20240712;
tables model2_quintile*perci;
run;

proc means data=manu.uniqhosp_20240712 mean stddev;
var model2_mu;
class model2_quintile;
run;

*create lowest vs highest perci variable;
data manu.uniqhosp_20240712;
set manu.uniqhosp_20240712 /*(drop=veryhigh_perci)*/;
if model2_quintile = 0 then model2_veryhigh_perci_new = 0;
	else if model2_quintile = 4 then model2_veryhigh_perci_new = 1;
run;

proc freq data = manu.uniqhosp_20240712;
tables model2_veryhigh_perci_new (cvshock_ICU_newoccur_hosp respfail_ICU_newoccur_hosp
		renalfail_ICU_newoccur_hosp coagfail_ICU_newoccur_hosp
		liverfail_ICU_newoccur_hosp any_organ_fail pallcare_days_1_3
		pallcare_ICU_newoccur_hosp pallcare_anyICUday1_11_hosp icu_mort)*model2_veryhigh_perci_new / relrisk;
run;

*need to get p values for odds ratios;
%let var = any_organ_fail;
proc freq data= manu.uniqhosp_20240712;
tables &var*model2_veryhigh_perci_new / relrisk;
run;
ods select CLoddsWald;
proc logistic data=manu.uniqhosp_20240712;
model model2_veryhigh_perci_new(event='1')=&var / clodds=wald orpvalue;
run;

				
/*/*/* Model 2 Quintiles: Figures 2 and Supplement appendix B Figure 1 */*/*/

*Create variables for 'Any Late-Onset Organ Failure';
data manu.uniqhosp_20240712;
set manu.uniqhosp_20240712;
if cvshock_ICU_newoccur_hosp = 1 or respfail_ICU_newoccur_hosp = 1 or 
		renalfail_ICU_newoccur_hosp = 1 or coagfail_ICU_newoccur_hosp = 1 or 
		liverfail_ICU_newoccur_hosp = 1 then any_organ_fail = 1;
											else any_organ_fail = 0;
run;


*create any day palliative care variable (received pall care on any ICU day 1 through 11);
proc contents data=manu.uniqhosp_20240712;run;
data manu.uniqhosp_20240712;
set manu.uniqhosp_20240712;
if pallcare_ICUday1_hosp = 1 or pallcare_ICUday2_hosp = 1 or pallcare_ICUday3_hosp = 1 or
	pallcare_ICUday4_hosp = 1 or pallcare_ICUday5_hosp = 1 or pallcare_ICUday6_hosp = 1 or
		pallcare_ICUday7_hosp = 1 or pallcare_ICUday8_hosp = 1 or pallcare_ICUday9_hosp = 1 or
	pallcare_ICUday10_hosp = 1 or pallcare_ICUday11_hosp = 1 then pallcare_anyICUday1_11_hosp = 1;
	else pallcare_anyICUday1_11_hosp = 0 ;
run;


**new scatterplots;

*Early Palliative Care;
*count how many early palliative care consults per sta6a;
proc sql;
create table ep as
select distinct a.sta6a, a.early_pallcare_count, a.early_pallcare_count/b.sta6a_total as pct format=percent8.1
from (select sta6a, count(*) as early_pallcare_count from manu.uniqhosp_20240712 where pallcare_days_1_3 = 1 group by sta6a) a
inner join (select sta6a, count(*) as sta6a_total from manu.uniqhosp_20240712 group by sta6a) b
	on a.sta6a = b.sta6a;
quit;

*check;
proc freq data=manu.uniqhosp_20240712;
tables sta6a*pallcare_days_1_3;
run;

*merge mu (perci adjusted proportion from model 2 log reg) into sta6a data set;
proc sql;
create table manu.ep_perci as
select distinct a.*, b.model2_mu
from ep a
left join manu.uniqhosp_20240712 b
	on a.sta6a = b.sta6a;
quit;

proc means data=ep_perci min max mean;
var model2_mu;
run;

*create scatterplot;
ods graphics on;

*run a beta regression (can model y variable as a continous value between 0 and 1;

*Early Palliative Care;
proc glimmix data=manu.ep_perci;
model model2_mu = pct / dist=beta link=logit solution or cl;
output out=gmxoutearly pred(ilink)=gpredy lcl(ilink)=lower ucl(ilink)=upper;
run;

proc sort data=gmxoutearly;
by gpredy;
run;

proc sgplot data=gmxoutearly noautolegend;
scatter  x=pct y= model2_mu /jitter;
series y=gpredy x=pct; 
xaxis label="Proportion of ICU admits with early palliative care" labelattrs=(size=12) valueattrs=(size=12);
yaxis label="Probability of persistent critical illness" labelattrs=(size=12) valueattrs=(size=12) grid;
inset "r(*ESC*){sub 's'}=-0.14, p=0.17" /textattrs=(size=11);
run;

*get correlation coeff and p;
ods graphics on;
proc univariate data=gmxoutearly plot normal;
var pct model2_mu;
run;

proc corr data=gmxoutearly spearman;
var pct model2_mu;
run;

*Late Palliative Care;
*count how many early palliative care consults per sta6a;
proc sql;
create table lp as
select distinct a.sta6a, a.late_pallcare_count, a.late_pallcare_count/b.sta6a_total as pct /*format=percent8.3*/
from (select sta6a, count(*) as late_pallcare_count from manu.uniqhosp_20240712 where pallcare_ICU_newoccur_hosp = 1 group by sta6a) a
inner join (select sta6a, count(*) as sta6a_total from manu.uniqhosp_20240712 group by sta6a) b
	on a.sta6a = b.sta6a;
quit;

*check;
proc freq data=manu.uniqhosp_20240712;
tables sta6a*pallcare_ICU_newoccur_hosp;
run;

*merge mu (perci adjusted proportion from model 2 log reg) into sta6a data set;
proc sql;
create table manu.lp_perci as
select distinct a.*, b.model2_mu
from lp a
left join manu.uniqhosp_20240712 b
	on a.sta6a = b.sta6a;
quit;

proc means data=manu.lp_perci min max mean n;
var model2_mu;
run;

*create scatterplot;
ods graphics on;
*run a beta regression (can model y variable as a continous value between 0 and 1;
proc glimmix data=manu.lp_perci;
model model2_mu = pct / dist=beta link=logit solution or cl;
output out=gmxoutlate pred(ilink)=gpredy lcl(ilink)=lower ucl(ilink)=upper;
run;

proc sort data=gmxoutlate;
by gpredy;
run;

proc sgplot data=gmxoutlate noautolegend;
scatter  x=pct y= model2_mu /jitter;
series y=gpredy x=pct; 
xaxis label="Proportion of ICU admits with late palliative care" labelattrs=(size=12) valueattrs=(size=12);
yaxis label="Probability of persistent critical illness" labelattrs=(size=12) valueattrs=(size=12) grid;
inset "r(*ESC*){sub 's'}=0.23, p=0.02" /textattrs=(size=11);
run;

*get correlation coeff and p;
ods graphics on;
proc univariate data=gmxoutlate plot normal;
var pct model2_mu;
run;

proc corr data=gmxoutlate spearman;
var pct model2_mu;
run;

*Any Palliative Care;
proc sql;
create table evp as
select distinct a.sta6a, a.ever_pallcare_count, a.ever_pallcare_count/b.sta6a_total as pct format=percent8.1
from (select sta6a, count(*) as ever_pallcare_count from manu.uniqhosp_20240712 where pallcare_anyICUday1_11_hosp = 1 group by sta6a) a
inner join (select sta6a, count(*) as sta6a_total from manu.uniqhosp_20240712 group by sta6a) b
	on a.sta6a = b.sta6a;
quit;

*merge mu (perci adjusted proportion from model 2 log reg) into sta6a data set;
proc sql;
create table manu.evp_perci as
select distinct a.*, b.model2_mu
from evp a
left join manu.uniqhosp_20240712 b
	on a.sta6a = b.sta6a;
quit;

proc means data=evp_perci min max mean;
var model2_mu;
run;

*create scatterplot;
ods graphics on;
*run a beta regression (can model y variable as a continous value between 0 and 1;
proc glimmix data=manu.evp_perci;
model model2_mu = pct / dist=beta link=logit solution or cl;
output out=gmxoutever pred(ilink)=gpredy lcl(ilink)=lower ucl(ilink)=upper;
run;

proc sort data=gmxoutever;
by gpredy;
run;

proc sgplot data=gmxoutever noautolegend;
scatter  x=pct y= model2_mu /jitter;
series y=gpredy x=pct; 
xaxis label="Proportion of ICU admits with ever palliative care" labelattrs=(size=12) valueattrs=(size=12);
yaxis label="Probability of persistent critical illness" labelattrs=(size=12) valueattrs=(size=12) grid;
inset "r(*ESC*){sub 's'}=-0.05, p=0.58" /textattrs=(size=11);
run;

*get correlation coeff and p;
ods graphics on;
proc univariate data=gmxoutever plot normal;
var pct model2_mu;
run;

proc corr data=gmxoutever spearman;
var pct model2_mu;
run;

*Late-onset organ failure;
proc sql;
create table of as
select distinct a.sta6a, a.any_organ_fail_count, a.any_organ_fail_count/b.sta6a_total as pct format=percent8.1
from (select sta6a, count(*) as any_organ_fail_count from manu.uniqhosp_20240712 where any_organ_fail = 1 group by sta6a) a
inner join (select sta6a, count(*) as sta6a_total from manu.uniqhosp_20240712 group by sta6a) b
	on a.sta6a = b.sta6a;
quit;

*merge mu (perci adjusted proportion from model 2 log reg) into sta6a data set;
proc sql;
create table manu.of_perci as
select distinct a.*, b.model2_mu
from of a
left join manu.uniqhosp_20240712 b
	on a.sta6a = b.sta6a;
quit;

proc means data=of_perci min max mean;
var model2_mu;
run;

*create scatterplot;
*run a beta regression (can model y variable as a continous value between 0 and 1;
proc glimmix data=manu.of_perci;
model model2_mu = pct / dist=beta link=logit solution or cl;
output out=gmxoutof pred(ilink)=gpredy lcl(ilink)=lower ucl(ilink)=upper;
run;

proc freq data=manu.of_perci;
tables any_organ_fail_count*sta6a;
run;

proc sort data=gmxoutof;
by gpredy;
run;

proc sgplot data=gmxoutof noautolegend;
scatter  x=pct y= model2_mu /jitter;
series y=gpredy x=pct; 
xaxis label="Proportion of ICU admits with any new late-onset organ failure" labelattrs=(size=12) valueattrs=(size=12);
yaxis label="Probability of persistent critical illness" labelattrs=(size=12) valueattrs=(size=12) grid;
inset "r(*ESC*){sub 's'}=0.65, p <.0001" /textattrs=(size=11) position=topright;
run;

*get correlation coeff and p;
ods graphics on;
proc univariate data=gmxoutof plot normal;
var pct model2_mu;
run;

proc corr data=gmxoutof spearman;
var pct model2_mu;
run;
