#!/bin/bash


function print_usage() {
  echo "Usage: $(basename $0) [options] <group>"
  echo
  echo "Options:"
  echo 
  echo "  --repo REPOSITORY     Repository mirror to use"
  echo "  --arch ARCH           Architecture mirror to use"
  echo
}

REPO=fedora-35
ARCH=x86_64

while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in
    --repo)
      REPO="$2"
      shift;
      shift;
      ;;
    --arch)
      ARCH="$2"
      shift;
      shift;
      ;;
 
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done
	
set -- "${POSITIONAL[@]}"


if [ $# -ne 1 ]
then
	print_usage
	exit 1;
fi

GROUP=$1
MIRROR=$(curl -s "https://mirrors.fedoraproject.org/mirrorlist?repo=$REPO&arch=$ARCH" | tail -n +2 | head -n 1)
GROUP_HREF=$(curl -s ${MIRROR}repodata/repomd.xml | xmllint --xpath "string(/*[local-name()='repomd']/*[local-name()='data' and @type=\"group\"]/*[local-name()='location']/@href)" -)

curl -s ${MIRROR}${GROUP_HREF} | \
	xmllint --xpath \
	"/comps/group[id[contains(text(),\"$1\")]]/packagelist/packagereq/text()" - | \
	xargs dnf download --alldeps --resolve
