#!/bin/bash

bash <<"%EOF%"
source /users/praphkum/.bashrc
export PATH=/auto/savbu-asic-files/node/local/bin:$PATH
export PATH=/auto/savbu-asic-files/mongodb/bin:$PATH
/auto/savbu-asic-files/node/local/bin/coffee /auto/savbu-asic-files/regression-dashboard/loadDataToDB.coffee --dir='/users/regress/uregress/bodega.latest' --file='results.log'
%EOF%