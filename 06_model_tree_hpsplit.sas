/*--------------------------------------------------------------
  Model: Decision Tree (PROC HPSPLIT)

  Purpose:
    - Train a decision tree on TRAIN
    - Generate scoring code
    - Score TEST to produce PD = P(default=1)
    - Evaluate: AUC, KS, Confusion Matrix @ cutoff, Deciles/Lift

  Inputs:
    - work.train
    - work.test

  Outputs:
    - /workspaces/myfolder/credit-risk-sas/tree_score_code.sas
    - work.score_tree_test          (default + PD)
    - work.tree_auc_test            (Association table with c-statistic)
    - work.tree_roc_test            (ROC points for KS)
    - work.tree_ks_test             (single-row KS)
    - work.tree_decile_table2       (deciles with lift + cum capture)
--------------------------------------------------------------*/

options nodate nonumber;
ods graphics on;

%let target = default;
%let seed   = 42;
%let cutoff = 0.20;

/* Consistent variable lists across models */
%let interval_vars =
  term_m int_rate_num installment dti_clean2 fico_mid2 loan_amnt_cap
  revol_util_clean2 log_inc open_acc_cap total_acc_cap revol_bal_cap;

%let nominal_vars =
  home_ownership_c verification_status_c purpose_c emp_length_grp
  grade_c sub_grade_c application_type_c addr_state_c;

/*--------------------------------------------------------------
  1) Train tree + export scoring code
--------------------------------------------------------------*/
proc hpsplit data=work.train seed=&seed assignmissing=similar;
  class &target &nominal_vars;

  model &target =
    &interval_vars
    &nominal_vars;

  grow entropy;
  prune costcomplexity;

  code file="/workspaces/myfolder/credit-risk-sas/tree_score_code.sas";
run;

/*--------------------------------------------------------------
  2) Score TEST using generated scoring code
--------------------------------------------------------------*/
data work.score_tree_raw;
  set work.test;
  %include "/workspaces/myfolder/credit-risk-sas/tree_score_code.sas";
run;

data work.score_tree_test;
  set work.score_tree_raw;

  /* Standardise PD = P(default=1) */
  PD = P_default1;

  keep &target PD;
run;

/*--------------------------------------------------------------
  3) Model performance on TEST: AUC + ROC + KS
--------------------------------------------------------------*/
ods exclude all;
ods output Association=work.tree_auc_test;
proc logistic data=work.score_tree_test;
  model &target(event='1') = PD;
  score data=work.score_tree_test out=work._tree_score_dummy outroc=work.tree_roc_test;
run;
ods exclude none;

/* KS from ROC table */
data work.tree_ks_calc;
  set work.tree_roc_test;
  ks = _sensit_ - _1mspec_;
run;

proc sql;
  create table work.tree_ks_test as
  select max(ks) as KS format=8.4
  from work.tree_ks_calc;
quit;

/*--------------------------------------------------------------
  4) Confusion matrix at cutoff (bank-style operating point)
--------------------------------------------------------------*/
data work.tree_conf;
  set work.score_tree_test;
  pred = (PD >= &cutoff);
run;

title "Decision Tree (HPSPLIT) - Test Confusion Matrix (Cutoff=&cutoff)";
proc freq data=work.tree_conf;
  tables &target*pred / norow nocol nopercent;
run;
title;

/*--------------------------------------------------------------
  5) Deciles + lift + cumulative bad capture (bank standard)
--------------------------------------------------------------*/
data work.tree_scored_clean;
  set work.score_tree_test;
  if missing(PD) then delete;
run;

proc rank data=work.tree_scored_clean out=work.tree_rank groups=10 descending ties=low;
  var PD;
  ranks decile;
run;

data work.tree_rank;
  set work.tree_rank;
  decile = decile + 1;
run;

proc sql;
  create table work.tree_decile_table as
  select
    decile,
    count(*) as n,
    sum(&target) as bads,
    mean(&target) as bad_rate format=percent8.2,
    mean(PD) as avg_pd format=8.4
  from work.tree_rank
  group by decile
  order by decile;
quit;

proc sql noprint;
  select sum(bads) into :total_bads from work.tree_decile_table;
  select sum(n)    into :total_n    from work.tree_decile_table;
quit;

data work.tree_decile_table2;
  set work.tree_decile_table;
  retain cum_bads 0 cum_n 0;

  cum_bads + bads;
  cum_n    + n;

  pct_bads_captured = cum_bads / &total_bads;
  pop_pct           = cum_n / &total_n;

  overall_bad_rate  = &total_bads / &total_n;
  lift              = bad_rate / overall_bad_rate;

  format pct_bads_captured pop_pct overall_bad_rate percent8.2 lift 8.3;
run;

title "Decision Tree (HPSPLIT) - Test Deciles, Lift and Cumulative Bad Capture";
proc print data=work.tree_decile_table2 noobs; run;
title;

/*--------------------------------------------------------------
  6) Executive summary printouts (AUC + KS)
--------------------------------------------------------------*/
title "Decision Tree (HPSPLIT) - Test AUC (c-statistic)";
proc print data=work.tree_auc_test; run;

title "Decision Tree (HPSPLIT) - Test KS";
proc print data=work.tree_ks_test; run;

title;
