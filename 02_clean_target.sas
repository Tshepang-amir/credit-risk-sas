/* Create a clean binary target (default) from loan_status
   Keep only loans with final outcomes (Fully Paid vs Charged Off/Default)
*/

data work.lc_model_base;
  set work.lc_raw;

  length loan_status_clean $40;
  loan_status_clean = strip(loan_status);

  /* Target: 1 = default/bad, 0 = non-default/good */
  if loan_status_clean in ("Charged Off","Default",
                           "Does not meet the credit policy. Status:Charged Off") then default=1;
  else if loan_status_clean in ("Fully Paid",
                                "Does not meet the credit policy. Status:Fully Paid") then default=0;
  else default=.;

  /* Keep only labelled rows */
  if default in (0,1);

  /* Remove obvious ID/text leakage fields (optional but recommended now) */
  drop id member_id url desc title;
run;

/* Checks */
proc freq data=work.lc_model_base;
  tables loan_status_clean*default / missing;
run;

proc means data=work.lc_model_base n nmiss mean min p50 max;
  var annual_inc dti int_rate loan_amnt fico_range_low fico_range_high revol_util;
run;
