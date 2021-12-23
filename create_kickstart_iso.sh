#!/bin/bash

function print_usage() {
  echo "Usage: $(basename $0) [options] <kickstart> <iso>"
  echo
  echo "Options:"
  echo 
  echo "  -r, --repository DIRECTORY     Path to repository to copy repository from"
  echo
}

if [ $(uname -s) != Linux ]
then
  echo "Non-Linux systems are currently not supported."
  exit 1
fi

TEST_ISO=0
while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in
    -r|--repository)
      REPOSITORY="$2"
      shift;
      shift;
      ;;
    -t|--test)
      TEST_ISO=1
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
7z x -bb0 -o$ISODIR $ISO

# Setup kickstart
cp $KICKSTART $ISODIR/ks.cfg
sed -i "s/menu title .*/menu title $KICKSTART_NAME/" $ISODIR/isolinux/isolinux.cfg
sed -i "s/LABEL=[^ ]\+/LABEL=$LABEL/" $ISODIR/isolinux/isolinux.cfg
sed -i "s/initrd=initrd.img/initrd=initrd.img inst.repo=hd:LABEL=$LABEL:\/localrepo inst.ks=hd:LABEL=$LABEL/" $ISODIR/isolinux/isolinux.cfg

# Download RPMs
mkdir -p $ISODIR/localrepo
if [ -z $REPOSITORY ]
then
  $(dirname $0)/download_group_packages.sh --destdir $ISODIR/localrepo core && \
    awk '/^%packages/{flag=1;next}/^%end/{flag=0}flag' workstation.cfg  | grep -v "^-" | \
    xargs dnf download --destdir $ISODIR/localrepo --alldeps --resolve && \
    createrepo $ISODIR/localrepo
  if [ $? -ne 0 ]
  then
    echo "Failed to crete repository"
    exit 1
  fi
else
  cp -rf $REPOSITORY/* $ISODIR/localrepo
fi


pushd $ISODIR
genisoimage -U -r -v -T -J -joliet-long -V "$LABEL" -volset "$LABEL" -A "$LABEL" -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e images/efiboot.img -no-emul-boot -o ../$LABEL.iso .
popd
mv $TMPDIR/$LABEL.iso .
implantisomd5 $LABEL.iso

if [ $TEST_ISO -eq 1 ]
then
  echo "Testing ISO with QEMU"
  rm -rf $ISODIR
  qemu-img create -f qcow2 $TMPDIR/image.qcow2 20G
  qemu-system-x86_64 -accel kvm -m 1024 -cpu host -cdrom $LABEL.iso -boot d -hda $TMPDIR/image.qcow2
fi
