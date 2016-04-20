#!/bin/sh

if [ ! -d $HOME/rootfs ]; then
  echo "Creating rootfs"
  curl -OL https://cloud-images.ubuntu.com/releases/12.04.4/release-20120424/ubuntu-12.04-server-cloudimg-amd64-root.tar.gz
  mkdir -p $HOME/rootfs
  tar -C $HOME/rootfs -xf ubuntu-12.04-server-cloudimg-amd64-root.tar.gz
else
  echo "rootfs present, skipping"
fi
true
