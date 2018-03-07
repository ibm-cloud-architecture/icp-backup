#!/bin/bash

mount | grep kubelet | awk '{ system("umount "$3)}'
rm -rf /var/lib/kubelet/pods
