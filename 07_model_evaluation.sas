/*--------------------------------------------------------------
  Purpose:
    - Evaluate both Logistic Regression and Decision Tree models
    - Produce bank-friendly model diagnostics:
        * AUC (ROC)
        * KS statistic
        * Confusion matrix at a chosen cutoff
        * Decile table + lift
  Input: work.train, work.test
  Output: Various evaluation results for both models
--------------------------------------------------------------*/

/* Logistic Regression Evaluation */

/* 1) AUC (Train) for Logistic Regression */
title "AUC (Train) - Logistic Regression";
proc print data=work.auc_train noobs; run;
title;

/* 2) KS Statistic from ROC table (Logistic Regression) */
data work.ks_calc;
  set work.roc_test;
  ks = _sensit_ - _1mspec_;
run;

title "KS Statistic (Test) - Logistic Regression";
proc sql;
  select max(ks) as KS format=8.4 from work.ks_calc;
quit;
title;

/* 3) Confusion Matrix at cutoff for Logistic Regression */
%let cutoff = 0.20;

data work.conf;
  set work.scored_test2;
  pred = (PD >= &cutoff);
run;

title "Confusion Matrix (Test) - Logistic Regression at Cutoff=&cutoff";
proc freq data=work.conf;
  tables default*pred / norow nocol nopercent;
run;
title;

/* 4) Decile Table + Lift for Logistic Regression */
proc rank data=work.scored_test2 out=work.test_rank groups=10 descending;
  var PD;
  ranks decile;
run;

data work.test_rank;
  set work.test_rank;
  decile = decile + 1;
run;

proc sql;
  create table work.decile_table as
  select
    decile,
    count(*) as n,
    sum(default) as bads,
    mean(default) as bad_rate format=percent8.2,
    mean(PD) as avg_pd format=8.4
  from work.test_rank
  group by decile
  order by decile;
quit;

proc sql noprint;
  select sum(bads) into :total_bads from work.decile_table;
  select sum(n)    into :total_n    from work.decile_table;
quit;

data work.decile_table2;
  set work.decile_table;
  retain cum_bads 0 cum_n 0;

  cum_bads + bads;
  cum_n    + n;

  pct_bads_captured = cum_bads / &total_bads;
  pop_pct           = cum_n / &total_n;

  overall_bad_rate = &total_bads / &total_n;
  lift = bad_rate / overall_bad_rate;

  format pct_bads_captured pop_pct overall_bad_rate percent8.2 lift 8.3;
run;

title "Decile Table (Test) with Lift + Cumulative Bad Capture - Logistic Regression";
proc print data=work.decile_table2 noobs; run;
title;


/* Decision Tree (HPSPLIT) Evaluation */

/* 1) AUC (Train) for Decision Tree */
title "AUC (Train) - Decision Tree (HPSPLIT)";
proc print data=work.tree_auc_test noobs; run;
title;

/* 2) KS Statistic from ROC table (Decision Tree) */
data work.tree_ks_calc;
  set work.tree_roc_test;
  ks = _sensit_ - _1mspec_;
run;

title "KS Statistic (Test) - Decision Tree (HPSPLIT)";
proc sql;
  select max(ks) as KS format=8.4 from work.tree_ks_calc;
quit;
title;

/* 3) Confusion Matrix at cutoff for Decision Tree */
data work.tree_conf;
  set work.score_tree_test;
  pred = (PD >= &cutoff);
run;

title "Confusion Matrix (Test) - Decision Tree (HPSPLIT) at Cutoff=&cutoff";
proc freq data=work.tree_conf;
  tables default*pred / norow nocol nopercent;
run;
title;

/* 4) Decile Table + Lift for Decision Tree */
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
    sum(default) as bads,
    mean(default) as bad_rate format=percent8.2,
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

