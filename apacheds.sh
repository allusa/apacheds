#!/bin/bash

APACHEDS_INSTANCE=/var/lib/apacheds-2.0.0_M20/default

function wait_for_ldap {
	echo "Waiting for LDAP to be available "
	c=0


	until nmap -Pn -p10389 localhost | awk "\$1 ~ /$PORT/ {print \$2}" | grep open; #nc -z localhost 10389;
 	do
        echo "LDAP not up yet... retrying... ($c/20)"
 		echo "Waiting for ldap"
 		if [ $c -eq 20 ]; then
 			echo "TROUBLE!!! After [${c}] retries LDAP is still dead :("
 			exit 2
 		fi

 		sleep 4
 		c=$((c+1))
 	done

}

if [ -f /bootstrap/config.ldif ] && [ ! -f ${APACHEDS_INSTANCE}/conf/config.ldif_migrated ]; then
	echo "Using config file from /bootstrap/config.ldif"
	rm -rf ${APACHEDS_INSTANCE}/conf/config.ldif

	cp /bootstrap/config.ldif ${APACHEDS_INSTANCE}/conf/
	chown apacheds.apacheds ${APACHEDS_INSTANCE}/conf/config.ldif
fi

if [ -d /bootstrap/schema ]; then
	echo "Using schema from /bootstrap/schema directory"
	rm -rf ${APACHEDS_INSTANCE}/partitions/schema 

	cp -R /bootstrap/schema/ ${APACHEDS_INSTANCE}/partitions/
	chown -R apacheds.apacheds ${APACHEDS_INSTANCE}/partitions/
fi

# There should be no correct scenario in which the pid file is present at container start
rm -f ${APACHEDS_INSTANCE}/run/apacheds-default.pid 

/opt/apacheds-2.0.0_M20/bin/apacheds start default

wait_for_ldap


if [ -n "${BOOTSTRAP_FILE}" ]; then
	echo "Bootstraping Apache DS with Data from ${BOOTSTRAP_FILE}"
	
	ldapmodify -h localhost -p 10389 -D 'uid=admin,ou=system' -w secret -f $BOOTSTRAP_FILE
fi

trap "echo 'Stoping Apache DS';/opt/apacheds-2.0.0_M20/bin/apacheds stop default;exit 0" SIGTERM SIGKILL

while true
do
  tail -f /dev/null & wait ${!}
done
