/* Step 17: Create PD bands + a clean scored output for reporting */

%let pdvar=P_1;

/* Use test set scores for a clean demonstration output */
data work.scored_for_report;
  set work.scored_test_clean;

  length risk_band $10;

  /* Simple PD bands (tune later) */
  if &pdvar >= 0.30 then risk_band="High";
  else if &pdvar >= 0.12 then risk_band="Medium";
  else risk_band="Low";
run;

/* Band summary */
proc sql;
  create table work.band_summary as
  select
    risk_band,
    count(*) as n,
    mean(default) as bad_rate format=percent8.2,
    mean(&pdvar) as avg_pd format=8.4
  from work.scored_for_report
  group by risk_band
  order by calculated avg_pd desc;
quit;

proc print data=work.band_summary noobs; run;

/* Export a small sample for your repo (so GitHub isn’t huge) */
proc surveyselect data=work.scored_for_report out=work.scored_sample
  method=srs sampsize=2000 seed=42;
run;

proc export data=work.scored_sample
  outfile="/workspaces/myfolder/credit-risk-sas/scored_sample.csv"
  dbms=csv replace;
run;
