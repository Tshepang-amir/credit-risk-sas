/*--------------------------------------------------------------
  Adapted from 03b_collapse_rare_levels.sas in this repo.
  Logic unchanged: PROC FREQ to find rare categorical levels,
  collapse them into "OTHER" via by-group merges, then use a
  CALL SYMPUTX / SYMGETN feedback loop to merge a too-small
  "OTHER" home_ownership bucket into "RENT".
  The upstream *_c categorical columns are materialised here
  with upcase(strip(...)) of the real category fields in the
  inline sample (exactly what the 03 step produces).
--------------------------------------------------------------*/

/* Inline sample: a 60-row real slice of the project's scored data
   (a deterministic subset of scored_sample.csv from this repo),
   recreated here so the bundle runs self-contained.            */
data work.lc_sample;
  length home_ownership $12 verification_status $16 purpose $20 grade $2 sub_grade $4 emp_length $12 application_type $12 addr_state $4;
  infile datalines dsd truncover;
  input default P_1 P_0 loan_amnt installment int_rate_num term_m dti_clean fico_mid revol_util_clean log_annual_inc open_acc total_acc revol_bal annual_inc home_ownership $ verification_status $ purpose $ grade $ sub_grade $ emp_length $ application_type $ addr_state $;
datalines;
0,0.0332061441,0.9667938559,6000,187.77,7.91,36,17.92,797,4.4,10.799575577,10,16,2212,49000,MORTGAGE,Not Verified,debt_consolidation,A,A5,10+ years,Individual,CO
0,0.2550990512,0.7449009488,6000,214.73,17.27,36,23.03,662,76.4,11.695247022,16,21,20408,120000,MORTGAGE,Verified,debt_consolidation,D,D3,10+ years,Individual,CO
1,0.2882758226,0.7117241774,5475,200.67,18.99,36,33.47,672,41,11.589886506,11,27,3045,108000,MORTGAGE,Verified,debt_consolidation,E,E1,10+ years,Individual,FL
0,0.0989124299,0.9010875701,10000,318.79,9.17,36,13.9,677,63.6,10.545341439,13,23,12012,38000,MORTGAGE,Source Verified,credit_card,B,B2,10+ years,Individual,VA
0,0.162043328,0.837956672,12000,395.6,11.48,36,11.23,662,82,10.93310697,16,27,10139,56000,RENT,Not Verified,debt_consolidation,B,B5,10+ years,Individual,NY
1,0.5129525801,0.4870474199,30000,924.87,27.49,60,17.73,677,58.7,11.652687407,14,20,50634,115000,MORTGAGE,Verified,other,G,G2,1 year,Individual,CO
0,0.2271334356,0.7728665644,15000,512.6,13.99,36,28.43,677,56.6,11.884489021,17,23,17201,145000,MORTGAGE,Verified,debt_consolidation,C,C4,< 1 year,Individual,OH
0,0.5016370415,0.4983629585,20000,535.46,20.5,60,24.78,692,21.6,11.119882877,11,20,7041,67500,MORTGAGE,Source Verified,debt_consolidation,E,E4,8 years,Individual,PA
1,0.1287451465,0.8712548535,20000,652.7,10.78,36,17.54,692,46.6,11.751942365,22,39,25312,127000,MORTGAGE,Source Verified,credit_card,B,B4,9 years,Individual,TN
0,0.0920012392,0.9079987608,12000,378.76,8.49,36,17.99,672,61,11.695247022,10,24,5234,120000,MORTGAGE,Source Verified,debt_consolidation,B,B1,6 years,Individual,MD
0,0.0841188932,0.9158811068,6000,193.05,9.8,36,9.66,727,93.8,11.225243393,5,11,6847,75000,RENT,Source Verified,debt_consolidation,B,B3,< 1 year,Individual,CA
1,0.4503876805,0.5496123195,16000,399.97,17.27,60,31.84,667,62,11.002099841,16,35,21659,60000,MORTGAGE,Verified,other,D,D3,4 years,Individual,IL
0,0.2456094366,0.7543905634,20000,683.46,13.99,36,34.54,662,62,11.156250521,13,32,20543,70000,MORTGAGE,Verified,debt_consolidation,C,C4,10+ years,Individual,WI
0,0.6367846404,0.3632153596,11825,341.84,24.24,60,21.4,662,47,11.350406535,13,26,9632,85000,RENT,Source Verified,debt_consolidation,F,F3,8 years,Individual,TN
1,0.0587830737,0.9412169263,7500,233.27,7.49,36,20.96,697,5.4,10.165851817,13,51,2685,26000,OWN,Not Verified,other,A,A4,10+ years,Individual,NY
0,0.0739045146,0.9260954854,15000,473.45,8.49,36,28.43,732,35.2,10.491274217,14,44,18114,36000,MORTGAGE,Not Verified,debt_consolidation,B,B1,10+ years,Individual,OK
0,0.0534575567,0.9465424433,21000,662.83,8.49,36,19.89,767,37,11.429543856,12,21,37240,92000,MORTGAGE,Not Verified,debt_consolidation,B,B1,10+ years,Individual,HI
1,0.2020059425,0.7979940575,33000,1169.82,16.59,36,14.69,667,79,12.013700753,9,34,36204,165000,MORTGAGE,Source Verified,debt_consolidation,D,D2,2 years,Individual,IL
0,0.3022956621,0.6977043379,22025,807.24,18.99,36,18.56,692,86,11.884489021,9,23,11279,145000,RENT,Verified,credit_card,E,E1,< 1 year,Individual,TX
0,0.1946343761,0.8053656239,5600,189.88,13.44,36,7.99,672,91.9,10.736396675,10,14,10842,46000,RENT,Verified,debt_consolidation,C,C3,8 years,Individual,NY
1,0.2742368713,0.7257631287,12000,425.39,16.59,36,20.01,677,16.9,11.528306567,27,36,25714,101550,MORTGAGE,Verified,credit_card,D,D2,10+ years,Individual,PA
0,0.1178922484,0.8821077516,4000,128.7,9.8,36,31.02,672,100,11.512925465,13,28,84675,100000,RENT,Not Verified,debt_consolidation,B,B3,3 years,Individual,CA
0,0.2093827038,0.7906172962,7200,249.07,14.85,36,10.84,697,31.8,10.915088464,12,20,4616,55000,RENT,Source Verified,debt_consolidation,C,C5,2 years,Individual,CA
1,0.2817573995,0.7182426005,10000,345.92,14.85,36,25.91,697,25.4,10.203592145,9,26,3806,27000,RENT,Source Verified,major_purchase,C,C5,5 years,Individual,LA
0,0.6250584336,0.3749415664,19925,608.3,26.99,60,19.41,667,68.5,10.922334873,12,19,21025,55400,RENT,Verified,debt_consolidation,G,G1,3 years,Individual,MD
0,0.1236455177,0.8763544823,10000,315.63,8.49,36,9.44,697,31.3,11.695247022,28,34,10515,120000,RENT,Not Verified,debt_consolidation,B,B1,< 1 year,Individual,AZ
1,0.1487967522,0.8512032478,6400,212.55,11.99,36,20.13,672,66.1,10.691944913,13,33,7864,44000,MORTGAGE,Source Verified,debt_consolidation,C,C1,10+ years,Individual,MA
0,0.2267135003,0.7732864997,11750,395.23,12.88,36,18.28,667,30.3,10.239959789,11,28,6207,28000,RENT,Source Verified,debt_consolidation,C,C2,2 years,Individual,FL
0,0.1298151565,0.8701848435,15000,478.19,9.17,36,28.15,697,51.5,10.819778284,5,10,16482,50000,RENT,Not Verified,credit_card,B,B2,5 years,Individual,NY
1,0.0467504621,0.9532495379,16000,500.58,7.89,36,14.75,727,42.9,11.608235645,15,23,110958,110000,OWN,Verified,home_improvement,A,A5,10+ years,Individual,CA
0,0.1979202445,0.8020797555,4000,131.87,11.48,36,33.46,682,48.9,10.388995368,5,12,2542,32500,RENT,Source Verified,debt_consolidation,B,B5,5 years,Individual,CA
0,0.0388135751,0.9611864249,13000,404.33,7.49,36,10.77,747,13.7,11.289781914,14,27,4817,80000,MORTGAGE,Not Verified,debt_consolidation,A,A4,< 1 year,Individual,MN
1,0.1512822111,0.8487177889,24000,788.24,11.22,36,24.56,662,75.2,11.225243393,12,28,24077,75000,MORTGAGE,Verified,debt_consolidation,B,B5,< 1 year,Individual,MS
0,0.1997771892,0.8002228108,15000,482.61,9.8,36,25.06,662,78.9,11.156250521,17,21,17604,70000,RENT,Verified,home_improvement,B,B3,3 years,Individual,FL
0,0.0612204384,0.9387795616,5000,157.82,8.49,36,14.17,692,98.8,12.180754838,12,23,84853,195000,MORTGAGE,Source Verified,major_purchase,B,B1,10+ years,Individual,NJ
1,0.1803105899,0.8196894101,3000,101.35,13.18,36,12.78,677,67.3,10.596634733,8,27,5921,40000,RENT,Verified,debt_consolidation,C,C3,< 1 year,Individual,OH
0,0.1052693789,0.8947306211,10000,321.74,9.8,36,15.75,667,29.6,11.225243393,12,24,7813,75000,MORTGAGE,Not Verified,debt_consolidation,B,B3,10+ years,Individual,NY
0,0.0895933422,0.9104066578,5000,157.82,8.49,36,2.93,677,37.6,10.714417769,5,12,3121,45000,RENT,Not Verified,debt_consolidation,B,B1,10+ years,Individual,NY
1,0.2788672275,0.7211327725,30000,1069.44,16.99,36,20.54,672,76.7,11.289781914,11,18,13124,80000,MORTGAGE,Source Verified,debt_consolidation,D,D3,5 years,Individual,NY
0,0.1465297576,0.8534702424,35000,1162.34,11.99,36,13.6,662,83.9,11.918390573,8,24,24007,150000,MORTGAGE,Source Verified,credit_card,C,C1,3 years,Individual,FL
0,0.0516090489,0.9483909511,8000,246.99,6.99,36,14.05,717,19.1,11.002099841,14,43,8560,60000,OWN,Source Verified,credit_card,A,A3,10+ years,Individual,MA
1,0.4051250824,0.5948749176,35000,869.66,16.99,60,12.44,677,54.7,12.345834588,29,48,45385,230000,OWN,Source Verified,credit_card,D,D3,10+ years,Individual,TX
0,0.1934401022,0.8065598978,15000,482.61,9.8,36,24.33,672,27,10.621327346,15,30,8983,41000,RENT,Verified,credit_card,B,B3,9 years,Individual,MA
0,0.4544514877,0.5455485123,20000,492.66,16.59,60,32.31,662,20,11.134589024,14,49,799,68500,MORTGAGE,Verified,debt_consolidation,D,D2,10+ years,Individual,NY
1,0.1882181748,0.8117818252,12200,415.02,13.67,36,12.02,667,63,11.002099841,18,26,14642,60000,MORTGAGE,Verified,debt_consolidation,C,C4,6 years,Individual,MI
0,0.0890792413,0.9109207587,10000,312.95,7.91,36,19.63,692,34,10.491274217,8,15,6570,36000,RENT,Verified,credit_card,A,A5,4 years,Individual,TX
0,0.3316636703,0.6683363297,23750,570.14,15.41,60,24.44,702,76,10.896739326,11,24,24083,54000,OWN,Not Verified,debt_consolidation,D,D1,10+ years,Individual,MI
1,0.2713288017,0.7286711983,15000,502.46,12.59,36,27.36,662,65.3,10.714417769,17,24,21423,45000,RENT,Verified,debt_consolidation,C,C2,2 years,Individual,CA
0,0.0291810462,0.9708189538,24000,739.85,6.89,36,8.37,717,75,11.849397702,10,29,79774,140000,MORTGAGE,Source Verified,debt_consolidation,A,A3,10+ years,Individual,CA
0,0.1551830919,0.8448169081,32000,1133.74,16.55,36,4.43,672,91.1,13.217673557,7,30,7290,550000,MORTGAGE,Source Verified,other,D,D2,2 years,Individual,WV
1,0.4226577668,0.5773422332,30000,794.65,19.99,60,15.76,692,30.1,11.652687407,9,14,10779,115000,MORTGAGE,Verified,debt_consolidation,E,E4,10+ years,Individual,MA
0,0.3272743021,0.6727256979,15000,523,15.41,36,35.73,667,94.4,10.799575577,17,37,23785,49000,RENT,Source Verified,debt_consolidation,D,D1,< 1 year,Individual,TX
0,0.1471931675,0.8528068325,20000,656.86,11.22,36,14.14,672,41.2,11.643953727,17,29,14784,114000,OWN,Not Verified,debt_consolidation,B,B5,6 years,Individual,CA
1,0.5055215934,0.4944784066,19700,762.48,22.99,36,34.44,662,60.6,10.911116952,22,30,40329,54782,RENT,Verified,debt_consolidation,F,F2,10+ years,Individual,AZ
0,0.0460135391,0.9539864609,28000,854.87,6.24,36,19.66,722,67.3,11.918390573,11,41,40452,150000,RENT,Not Verified,credit_card,A,A2,8 years,Individual,NC
0,0.4086106754,0.5913893246,15300,576.35,20.99,36,19.49,667,16.2,10.714417769,17,53,2531,45000,RENT,Source Verified,debt_consolidation,E,E5,10+ years,Individual,TX
1,0.4968984863,0.5031015137,15850,398.79,17.57,60,33.44,712,24.8,11.082142549,14,40,9701,65000,RENT,Verified,debt_consolidation,D,D4,2 years,Individual,MN
0,0.3762427226,0.6237572774,12000,277.18,13.67,60,19.24,667,30.7,10.545341439,12,39,10380,38000,OWN,Source Verified,debt_consolidation,C,C4,10+ years,Individual,FL
0,0.1692482563,0.8307517437,11400,371.29,10.64,36,24.43,667,70,11.238488619,16,42,14777,76000,RENT,Verified,debt_consolidation,B,B4,7 years,Individual,CA
1,0.1541254932,0.8458745068,7000,227.98,10.64,36,18.18,677,56.9,10.596634733,8,10,6035,40000,RENT,Source Verified,debt_consolidation,B,B4,2 years,Individual,IL
;
run;

/* Materialise the *_c columns that 03b consumes (as 03 would) */
data work.lc_model;
  set work.lc_sample;
  length home_ownership_c purpose_c $40;
  home_ownership_c = upcase(strip(home_ownership));
  purpose_c        = upcase(strip(purpose));
run;

%let IN  = work.lc_model;
%let OUT = work.lc_model_final;

%let min_pct   = 0.10;   /* rare threshold: 0.10% */
%let min_count = 50;     /* hard minimum count to avoid tiny classes */

data work._base;
  set &IN;
  home_ownership_c = upcase(strip(home_ownership_c));
  purpose_c        = upcase(strip(purpose_c));
run;

proc freq data=work._base noprint;
  tables home_ownership_c / out=work._freq_home;
  tables purpose_c        / out=work._freq_purpose;
run;

data work._rare_home;
  set work._freq_home;
  rare = (percent < &min_pct) or (count < &min_count);
  keep home_ownership_c rare;
run;

data work._rare_purpose;
  set work._freq_purpose;
  rare = (percent < &min_pct) or (count < &min_count);
  keep purpose_c rare;
run;

proc sort data=work._base;       by home_ownership_c; run;
proc sort data=work._rare_home;  by home_ownership_c; run;

data work._tmp1;
  merge work._base(in=a) work._rare_home;
  by home_ownership_c;
  if a;

  length home_ownership_c2 $40;
  home_ownership_c2 = home_ownership_c;
  if rare=1 then home_ownership_c2 = "OTHER";
  drop rare;
run;

proc sort data=work._tmp1;          by purpose_c; run;
proc sort data=work._rare_purpose;  by purpose_c; run;

data work._tmp2;
  merge work._tmp1(in=a) work._rare_purpose;
  by purpose_c;
  if a;

  length purpose_c2 $40;
  purpose_c2 = purpose_c;
  if rare=1 then purpose_c2 = "OTHER";
  drop rare;
run;

/* If OTHER home_ownership is still tiny, merge into RENT */
proc freq data=work._tmp2 noprint;
  tables home_ownership_c2 / out=work._home_after;
run;

data _null_;
  set work._home_after;
  if home_ownership_c2 = "OTHER" then call symputx("home_other_n", count);
run;

data work._tmp3;
  set work._tmp2;
  if symgetn("home_other_n") < &min_count then do;
    if home_ownership_c2 = "OTHER" then home_ownership_c2 = "RENT";
  end;
run;

data &OUT;
  set work._tmp3;
  drop home_ownership_c purpose_c;
  rename home_ownership_c2 = home_ownership_c
         purpose_c2        = purpose_c;
run;

/*--------------------------------------------------------------
  Re-checks (clean, bank-style)
--------------------------------------------------------------*/
title "Post-collapse category checks";
proc freq data=&OUT;
  tables home_ownership_c purpose_c / missing;
run;

title "Target balance check";
proc freq data=&OUT;
  tables default;
run;

title;
