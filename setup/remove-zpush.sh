#!/bin/bash
#
# Remove Z-Push (Exchange ActiveSync)
# -----------------------------------
#
# This fork doesn't install Z-Push: mail is reached over IMAP/SMTP and
# contacts/calendars over CalDAV/CardDAV, so the extra PHP application was
# only attack surface. Remove what earlier versions installed.

source setup/functions.sh # load our functions

if [ -d /usr/local/lib/z-push ]; then
	echo "Removing Z-Push (Exchange/ActiveSync server)..."
fi
rm -rf /usr/local/lib/z-push /var/lib/z-push /var/log/z-push
rm -f /usr/sbin/z-push-admin /usr/sbin/z-push-top /etc/logrotate.d/z-push
