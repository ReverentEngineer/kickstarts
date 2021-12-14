#!/bin/bash

function get_mirror() {
  if [ $# -ne 2 ]
  then
    echo "Usage: get_mirror <repo> <arch>"
    return 1
  fi
  REPO=$1
  ARCH=$2
  curl -s "https://mirrors.fedoraproject.org/mirrorlist?repo=$REPO&arch=$ARCH" | grep http | head -n 1 
}
