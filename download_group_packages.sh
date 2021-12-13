#!/bin/bash

if [ $# -ne 1 ]
then
	echo "Usage: $(basename $0) <group>"
	exit 1;
fi

GROUP=$1
REPO=fedora-35
ARCH=x86_64

MIRROR=$(curl -s "https://mirrors.fedoraproject.org/mirrorlist?repo=$REPO&arch=$ARCH" | tail -n +2 | head -n 1)
GROUP_HREF=$(curl -s ${MIRROR}repodata/repomd.xml | xmllint --xpath "string(/*[local-name()='repomd']/*[local-name()='data' and @type=\"group\"]/*[local-name()='location']/@href)" -)

curl -s ${MIRROR}${GROUP_HREF} | \
	xmllint --xpath \
	"/comps/group[id[contains(text(),\"$1\")]]/packagelist/packagereq/text()" - | \
	xargs dnf download --alldeps --resolve
