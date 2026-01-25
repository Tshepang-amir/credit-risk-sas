/*--------------------------------------------------------------
  Purpose:
    - Collapse rare categorical levels into "OTHER"
    - Then, if OTHER is still too small, merge OTHER into a stable
      dominant bucket (bank-friendly, avoids tiny classes)

  Input:  work.lc_model
  Output: work.lc_model_final
--------------------------------------------------------------*/

%let IN  = work.lc_model;
%let OUT = work.lc_model_final;

%let min_pct   = 0.10;   /* rare threshold: 0.10% */
%let min_count = 50;     /* hard minimum count to avoid tiny classes */

/*--------------------------------------------------------------
  0) Standardise casing/whitespace first (prevents merge mismatch)
--------------------------------------------------------------*/
data work._base;
  set &IN;

  home_ownership_c      = upcase(strip(home_ownership_c));
  purpose_c             = upcase(strip(purpose_c));

run;

/*--------------------------------------------------------------
  1) Frequency tables + rare flags
--------------------------------------------------------------*/
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

/*--------------------------------------------------------------
  2) Collapse rare into OTHER (safe with formats/lengths)
--------------------------------------------------------------*/
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

/*--------------------------------------------------------------
  3) Final tidy-up: if OTHER is still tiny, merge into a stable bucket
     - home_ownership: merge OTHER -> RENT (or MORTGAGE if you prefer)
     - purpose: keep OTHER (usually fine), but you can also merge if tiny
--------------------------------------------------------------*/

/* HOME_OWNERSHIP: find OTHER count after collapsing */
proc freq data=work._tmp2 noprint;
  tables home_ownership_c2 / out=work._home_after;
run;

data _null_;
  set work._home_after;
  if home_ownership_c2 = "OTHER" then call symputx("home_other_n", count);
run;

/* Apply rule: if OTHER < min_count then merge it into RENT */
data work._tmp3;
  set work._tmp2;

  if symgetn("home_other_n") < &min_count then do;
    if home_ownership_c2 = "OTHER" then home_ownership_c2 = "RENT";
  end;

run;

/* PURPOSE: optional similar rule (default is to keep OTHER) */
proc freq data=work._tmp3 noprint;
  tables purpose_c2 / out=work._purpose_after;
run;

data _null_;
  set work._purpose_after;
  if purpose_c2 = "OTHER" then call symputx("purpose_other_n", count);
run;

/* If you WANT to merge purpose OTHER when tiny, set this flag to 1 */
%let merge_purpose_other = 0;

data &OUT;
  set work._tmp3;

  if &merge_purpose_other = 1 then do;
    if symgetn("purpose_other_n") < &min_count then do;
      /* Merge OTHER -> DEBT_CONSOLIDATION (dominant, stable) */
      if purpose_c2 = "OTHER" then purpose_c2 = "DEBT_CONSOLIDATION";
    end;
  end;

  /* Replace originals with collapsed versions */
  drop home_ownership_c purpose_c;
  rename home_ownership_c2 = home_ownership_c
         purpose_c2        = purpose_c;
run;

/*--------------------------------------------------------------
  4) Re-checks (clean, bank-style)
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
