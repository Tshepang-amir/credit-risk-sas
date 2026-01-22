data work.hello;
  length msg $60;
  msg="Hello from Workbench running SAS";
run;

proc print data=work.hello; run;
