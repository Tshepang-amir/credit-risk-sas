/* Step 14: Baseline PD model (Logistic Regression) + simple train/test split */

%let seed=42;

/* 70/30 split */
proc surveyselect data=work.lc_fe out=work.lc_split
  samprate=0.70 method=srs seed=&seed outall;
run;

data work.train work.test;
  set work.lc_split;
  if selected then output work.train;
  else output work.test;
run;

/* Train logistic regression */
ods exclude all;
ods output Association=work.assoc_train  /* contains AUC */
           ParameterEstimates=work.pe_train;
proc logistic data=work.train descending;
  class home_ownership verification_status purpose emp_length grade application_type
        / param=glm;
  model default(event='1') =
       loan_amnt term_m int_rate_num installment dti_clean
       fico_mid revol_bal revol_util_clean open_acc total_acc
       log_annual_inc
       home_ownership verification_status purpose emp_length grade application_type;
  score data=work.test out=work.scored_test fitstat outroc=work.roc_test;
run;
ods exclude none;

/* Show AUC */
proc print data=work.assoc_train; run;

/* Compute KS from ROC table */
data work.ks_calc;
  set work.roc_test;
  ks = _sensit_ - _1mspec_;
run;

proc sql;
  select max(ks) as KS format=8.4 from work.ks_calc;
quit;

/* Quick sanity check: default rate in train vs test */
proc freq data=work.train; tables default; run;
proc freq data=work.test;  tables default; run;
