/* Import LendingClub accepted loans CSV into SAS */

%let project=/workspaces/myfolder/credit-risk-sas;
%let file=accepted_2007_to_2018Q4.csv;

proc import datafile="&project./&file."
    out=work.lc_raw
    dbms=csv
    replace;
    guessingrows=max;
    getnames=yes;
run;

/* Quick check */
proc contents data=work.lc_raw; run;
proc print data=work.lc_raw(obs=5); run;
