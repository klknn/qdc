#!/bin/bash
set -euo pipefail

if [ ! -d qbe/ ]; then
    echo "== Installing QBE =="
    git clone git://c9x.me/qbe.git
    cd qbe
    # git checkout f1b21d145ba03c6052b4b722dc457f8e944e6fca
    make
    cd -
else
    echo "== Updating QBE =="
    cd qbe
    git pull
    make
    cd -
fi

echo "== Testing =="
dub lint
dub test -b=unittest-cov
./qdc test.d
./a.out
