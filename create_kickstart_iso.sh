#!/bin/bash

function print_usage() {
  echo "Usage: $(basename $0) [options] <kickstart> <iso>"
  echo
  echo "Options:"
  echo 
  echo "  -r, --repository DIRECTORY     Path to repository to copy repository from"
  echo
}

while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in
    -r|--repository)
      REPOSITORY="$2"
      echo $REPOSITORY
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

if [ $# -ne 2 ]
then
  echo "Invalid number arguments."
  print_usage
  exit 1
fi

KICKSTART=$1
ISO=$2
TMPDIR=$(mktemp -d)
ISODIR=$TMPDIR/iso
KICKSTART_NAME=$(grep -Po '(?<=Kickstart Name: )(.*)' $KICKSTART)
LABEL="$(echo $KICKSTART_NAME | tr ' ' -)"

mkdir -p $ISODIR

trap "rm -rf $TMPDIR" EXIT

# Extract Base OS
7z x -o$ISODIR $ISO

# Setup kickstart
cp $KICKSTART $ISODIR/ks.cfg
sed -i "s/menu title .*/menu title $KICKSTART_NAME/" $ISODIR/isolinux/isolinux.cfg
sed -i "s/LABEL=[^ ]\+/LABEL=$LABEL/" $ISODIR/isolinux/isolinux.cfg
sed -i "s/initrd=initrd.img/initrd=initrd.img inst.repo=hd:LABEL=$LABEL:\/localrepo inst.ks=hd:LABEL=$LABEL/" $ISODIR/isolinux/isolinux.cfg

# Download RPMs
mkdir -p $ISODIR/localrepo
if [ -z $REPOSITORY ]
then
  dnf download --destdir $ISODIR/localrepo --alldeps --resolve kernel
  awk '/^%packages/{flag=1;next}/^%end/{flag=0}flag' workstation.cfg  | grep -v "^-" | xargs dnf download --destdir $ISODIR/localrepo --alldeps --resolve
  createrepo $ISODIR/localrepo
else
  cp -rf $REPOSITORY/* $ISODIR/localrepo
fi


pushd $ISODIR
genisoimage -U -r -v -T -J -joliet-long -V "$LABEL" -volset "$LABEL" -A "$LABEL" -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e images/efiboot.img -no-emul-boot -o ../$LABEL.iso .
popd
mv $TMPDIR/$LABEL.iso .
implantisomd5 $LABEL.iso
