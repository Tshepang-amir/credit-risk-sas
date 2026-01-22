/* Feature engineering + basic cleaning for modelling */

data work.lc_fe;
  set work.lc_model_base;

  /* Term: " 36 months" -> 36 */
  term_m = input(compress(term,,'kd'), best.);

  /* Interest rate is numeric already in this dataset, keep it as is */
  int_rate_num = int_rate;

  /* Clean DTI: 999 is a known placeholder in LendingClub exports */
  dti_clean = dti;
  if dti_clean = 999 then dti_clean = .;

  /* Revolving utilisation sometimes exceeds 100 or is missing */
  revol_util_clean = revol_util;
  if revol_util_clean > 100 then revol_util_clean = 100;

  /* Basic FICO mid (more stable than low/high separately) */
  fico_mid = mean(fico_range_low, fico_range_high);

  /* Log income (helps skew), guard zeros */
  if annual_inc > 0 then log_annual_inc = log(annual_inc);
  else log_annual_inc = .;

  /* Keep a focused modelling set (we’ll expand later if needed) */
  keep default
       loan_amnt term_m int_rate_num installment dti_clean
       fico_mid revol_bal revol_util_clean open_acc total_acc
       annual_inc log_annual_inc
       home_ownership verification_status purpose addr_state
       emp_length grade sub_grade application_type;
run;

/* Quick checks */
proc means data=work.lc_fe n nmiss mean min p50 max;
  var term_m int_rate_num installment dti_clean fico_mid loan_amnt revol_util_clean log_annual_inc;
run;

proc freq data=work.lc_fe;
  tables home_ownership verification_status purpose emp_length grade sub_grade application_type / missing;
run;
