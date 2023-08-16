Prerequisites:
None.

Install:
1. open cmd in current folder
2. execute "./terraform.exe init"
2. execute "./terraform.exe apply"

Extra steps(untested if the terraform applies these automatically):
1. add the following lines to your docker engine from docker settings 
   ``  "experimental": true,
       "metrics-addr" : "localhost:9323",``


Usage:
1. visit https://localhost:3000