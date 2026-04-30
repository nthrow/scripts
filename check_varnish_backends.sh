#!/usr/bin/env bash
# setup envars
CRIT=0
WARN=0
EXCLST="/etc/ops/vexclude.lst"

# check for exclusion list
if [ -f "$EXCLST" ]; then
  IFS=$'\r\n' GLOBIGNORE='*' command eval  'EXCLUDE=($(<$EXCLST))'
fi

# scrape active VCLs
IFS='
'
for i in $(varnishadm vcl.list |awk '$3>0 {print $4}')
do
# parse backends for each active VCL
  while IFS= read -r line
  do
    NAME=$(echo ${line} |awk '{print $1}')
    PROBE=$(echo ${line} |awk '{print $2}')
    STATUS=$(echo ${line} |awk '{print $3}')

# verify the backend is not intended to be excluded
    if [ ${#EXCLUDE[@]} -gt 0 ]; then
      for i in ${EXCLUDE[@]}
      do
        iName=$(printf "%s\n" "${i}")
        if [ "$iName" == "$NAME" ]; then
          break 2
        fi
      done
    fi

# grep the probe results, incrementing the counters for any NOK matches
    if [ "$PROBE" = "probe" ]; then
      if grep -qi "sick" <<< "$STATUS"; then
        echo "CRIT: Backend $NAME has fallen sick!"
        CRIT=$((CRIT+1))
      fi
    elif grep -qi "sick" <<< "$PROBE"; then
      echo "WARN: Backend $NAME was marked sick!"
      WARN=$((WARN+1))
    else
      echo "WARN: Backend $NAME probe was manually changed!"
      WARN=$((WARN+1))
    fi
  done < <(varnishadm backend.list "${i}.*" |awk 'NR>1')
done

# determine exit status
if [ $CRIT -ge 1 ]; then
  exit 2
elif [ $WARN -ge 1 ]; then
  exit 1
else
  echo "OKAY: All varnish backends are healthy!"
  exit 0
fi
