#!/bin/bash
# Record a Show session in a pseudo-terminal: keys "space space q", fixed TERM so that runs are comparable.
# Usage: ptyrec.sh COMMAND FILE TYPESCRIPT   (run from the directory containing FILE)
printf '  q' | TERM=xterm-256color script -qec "$1 $2" "$3" > /dev/null
