#!/bin/bash
#########################################################
# This is the asdz/mailinabox fork of Mail-in-a-Box.
#
# Install or update by running, as root:
#
#   curl -fsSL https://raw.githubusercontent.com/asdz/mailinabox/main/setup/bootstrap.sh | sudo bash
#
# or, on a box that already has the fork checked out:
#
#   sudo ~/mailinabox/setup/bootstrap.sh
#
# Releases are tagged vNN.P, where NN is the upstream Mail-in-a-Box release
# the fork is based on and P is the fork's patch number.
#########################################################

# Where the fork lives. Override with SOURCE=... for testing.
FORK_SOURCE=https://github.com/asdz/mailinabox

if [ -z "$TAG" ]; then
	# If a version to install isn't explicitly given as an environment
	# variable, then install the latest version. But the latest version
	# depends on the machine's version of Ubuntu. Existing users need to
	# be able to upgrade to the latest version available for that version
	# of Ubuntu to satisfy the migration requirements.
	#
	# Also, the system status checks read this script for TAG = (without the
	# space, but if we put it in a comment it would confuse the status checks!)
	# to get the latest version, so the first such line must be the one that we
	# want to display in status checks.
	#
	# Allow point-release versions of the major releases, e.g. 22.04.1 is OK.
	UBUNTU_VERSION=$( lsb_release -d | sed 's/.*:\s*//' | sed 's/\([0-9]*\.[0-9]*\)\.[0-9]/\1/' )
	if [ "$UBUNTU_VERSION" == "Ubuntu 22.04 LTS" ]; then
		# This machine is running Ubuntu 22.04, which is supported by
		# Mail-in-a-Box versions 60 and later.
		TAG=v78.1
	elif [ "$UBUNTU_VERSION" == "Ubuntu 18.04 LTS" ]; then
		# This machine is running Ubuntu 18.04, which is supported by
		# Mail-in-a-Box versions 0.40 through 5x.
		echo "Support is ending for Ubuntu 18.04."
		echo "Please immediately begin to migrate your data to"
		echo "a new machine running Ubuntu 22.04. See:"
		echo "https://mailinabox.email/maintenance.html#upgrade"
		TAG=v57a
	elif [ "$UBUNTU_VERSION" == "Ubuntu 14.04 LTS" ]; then
		# This machine is running Ubuntu 14.04, which is supported by
		# Mail-in-a-Box versions 1 through v0.30.
		echo "Ubuntu 14.04 is no longer supported."
		echo "The last version of Mail-in-a-Box supporting Ubuntu 14.04 will be installed."
		TAG=v0.30
	else
		echo "This script may be used only on a machine running Ubuntu 14.04, 18.04, or 22.04."
		exit 1
	fi
fi

# Are we running as root?
if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root. Did you leave out sudo?"
	exit 1
fi

if [ -z "${SOURCE:-}" ]; then
	SOURCE=$FORK_SOURCE
fi

# Clone the Mail-in-a-Box repository if it doesn't exist.
if [ ! -d "$HOME/mailinabox" ]; then
	if [ ! -f /usr/bin/git ]; then
		echo "Installing git . . ."
		apt-get -q -q update
		DEBIAN_FRONTEND=noninteractive apt-get -q -q install -y git < /dev/null
		echo
	fi

	echo "Downloading Mail-in-a-Box $TAG from $SOURCE . . ."
	git clone \
		-b "$TAG" --depth 1 \
		"$SOURCE" \
		"$HOME/mailinabox" \
		< /dev/null 2> /dev/null

	echo
fi

# Change directory to it.
cd "$HOME/mailinabox" || exit

# Boxes installed from upstream Mail-in-a-Box still fetch from upstream.
# Point them at the fork.
if [ "$(git remote get-url origin 2>/dev/null)" != "$SOURCE" ]; then
	echo "Switching update source to $SOURCE . . ."
	git remote set-url origin "$SOURCE"
fi

# Update it.
if [ "$TAG" != "$(git describe --always)" ]; then
	echo "Updating Mail-in-a-Box to $TAG . . ."

	# Remember who may sign releases *before* fetching the new code, so a
	# tampered release can't vouch for itself. The list is carried in the
	# repository (conf/allowed_signers), so it is trusted on first install
	# and enforced on every update after that.
	SIGNERS=$(mktemp)
	if [ -f conf/allowed_signers ]; then
		grep -Ev '^[[:space:]]*(#|$)' conf/allowed_signers > "$SIGNERS" || true
	fi

	git fetch --depth 1 --force --prune origin tag "$TAG"

	if [ -s "$SIGNERS" ]; then
		if ! git -c gpg.format=ssh -c gpg.ssh.program=ssh-keygen -c gpg.ssh.allowedSignersFile="$SIGNERS" verify-tag "$TAG" 2> /dev/null; then
			echo "Release $TAG is not signed by a key in conf/allowed_signers. Not updating."
			rm -f "$SIGNERS"
			exit 1
		fi
		echo "Release $TAG signature verified."
	else
		echo "Warning: no conf/allowed_signers yet, so release $TAG was not signature-checked."
	fi
	rm -f "$SIGNERS"

	if ! git checkout -q "$TAG"; then
		echo "Update failed. Did you modify something in $PWD?"
		exit 1
	fi
	echo
fi

# Start setup script.
setup/start.sh
