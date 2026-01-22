/* Step 16: Clean decile table by removing missing PD scores */

%let pdvar=P_1;  /* this is the PD score your logistic created */

data work.scored_test_clean;
  set work.scored_test;
  if missing(&pdvar) then delete;
run;

/* Deciles (10 equal groups) */
proc rank data=work.scored_test_clean out=work.test_rank groups=10 descending;
  var &pdvar;
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
    mean(&pdvar) as avg_pd format=8.4
  from work.test_rank
  group by decile
  order by decile;
quit;

proc sql noprint;
  select sum(bads) into :total_bads from work.decile_table;
  select sum(n) into :total_n from work.decile_table;
quit;

data work.decile_table2;
  set work.decile_table;
  retain cum_bads 0 cum_n 0;
  cum_bads + bads;
  cum_n + n;

  pct_bads_captured = cum_bads / &total_bads;
  pop_pct = cum_n / &total_n;

  overall_bad_rate = &total_bads / &total_n;
  lift = (bad_rate) / overall_bad_rate;

  format pct_bads_captured pop_pct percent8.2 lift 8.3 overall_bad_rate percent8.2;
run;

proc print data=work.decile_table2 noobs; run;
