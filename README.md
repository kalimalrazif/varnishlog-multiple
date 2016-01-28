# varnishlog_multiple
Perl script to multiplex varnishncsa file log into one per site log.

## To configure in debian with varnish 3.0.2


Add this line to /etc/init.d/varnishncsa 

LOG_FORMAT="%{Host}i %h %l %u %t \"%r\" %s %b \"%{Referer}i\" \"%{User-agent}i\""

and then modify 

DAEMON_OPTS="-a -w ${LOGFILE} -D -P ${PIDFILE} -F"

and at last

--chuid $USER --exec ${DAEMON} -- ${DAEMON_OPTS} "${LOG_FORMAT}" \


