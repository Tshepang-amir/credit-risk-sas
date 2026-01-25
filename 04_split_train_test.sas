/*--------------------------------------------------------------
  Purpose:
    - Create reproducible TRAIN/TEST split (70/30)
    - Stratify by target (default) to keep class balance stable
    - Produce audit checks for banks (counts + target rate)
  Input:  work.lc_model_final
  Output: work.train, work.test
--------------------------------------------------------------*/

%let IN   = work.lc_model_final;
%let seed = 42;
%let rate = 0.70;

proc sort data=&IN out=work._split_base;
  by default;
run;

/* Stratified random split (keeps default distribution consistent) */
proc surveyselect data=work._split_base out=work._split_flag
  method=srs samprate=&rate seed=&seed outall;
  strata default;
run;

data work.train work.test;
  set work._split_flag;
  if selected then output work.train;
  else output work.test;
  drop selected;
run;

/* ------------------------------------------------------------
   Audit checks: record counts and target distribution
------------------------------------------------------------ */
title "Train/Test row counts";
proc sql;
  select "TRAIN" as dataset, count(*) as n from work.train
  union all
  select "TEST"  as dataset, count(*) as n from work.test;
quit;

title "Train/Test default balance (should be very similar)";
proc freq data=work.train;
  tables default / nocum;
run;

proc freq data=work.test;
  tables default / nocum;
run;

title "Default rate check (mean of default)";
proc means data=work.train n mean;
  var default;
run;

proc means data=work.test n mean;
  var default;
run;

title;
