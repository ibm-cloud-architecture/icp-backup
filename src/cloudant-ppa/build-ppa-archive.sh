#!/bin/bash
#
# Licensed Material - Property of IBM
# 5724-I63, 5724-H88, (C) Copyright IBM Corp. 2018 - All Rights Reserved.
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corp.
#
# DISCLAIMER:
# The following source code is sample code created by IBM Corporation.
# This sample code is provided to you solely for the purpose of assisting you
# in the  use of  the product. The code is provided 'AS IS', without warranty or
# condition of any kind. IBM shall not be liable for any damages arising out of
# your use of the sample code, even if IBM has been advised of the possibility
# of such damages.
#
# Description
#   Build a helm and image PPA.
#
#  ASSUMPTIONS:
#   1. It is assumed that the helm chart has been archived and gzipped into a file with
#      the name of the chart, e.g. icp-cloudant-backup with a suffix of -chart-VERSION.tgz
#      where VERSION is Semver 2.0 version number, e.g., 0.1.0.  (Semver seems to be the
#      proper version numbering scheme to use here.)
#
#   2. Likewise the image file with a docker image is assumed to be named with the name
#      of the chart, e.g., icp-cloudant-backup with a suffix of -image-VERSION.tgz
#      The following command can be used to get an image in the locak registry into
#      a tgz file:
#         docker save ibmcase/icp-cloudant-backup | gzip > icp-cloudant-backup-image-0.1.0.tgz
#
function usage {
  echo ""
  echo "Usage: build-ppa-archive.sh [options]"
  echo "   --chart-name <chart_name>             - (required) The name of the chart."
  echo "   --chart-version <chart_version>       - (required) The version number of the chart file."
  echo "   --chart-home <chart_path>             - (required) The path to the home directory for charts."
  echo ""
  echo "   --image-name <image_name>             - (required) The name of the image."
  echo "   --image-version <image_version>       - (required) The version number of the image file."
  echo "   --image-tag <image_tag>               - (optional) The tag of the image.  Defaults to latest."
  echo "   --image-home <image_path>             - (required) The path to the home directory for images."
  echo ""
  echo "   --help|-h                             - emit this usage information"
  echo ""
  echo "Sample invocations (all on one line):"
  echo "In the sample below the chart and image .tgz files are in the user's home directory."
  echo "  ./build-ppa-archive.sh --chart-name icp-cloudant-backup "
  echo "                         --chart-version 0.1.0 --chart-home ~/  "
  echo "                         --image-name icp-cloudant-backup "
  echo "                         --image-version 0.1.0 --image-home ~/"
  echo ""
}

function info {
  local lineno=$1; shift
  local ts=$(date +[%Y/%m/%d-%T])
  echo "$ts $SCRIPT($lineno) $*"
}

############ "Main" starts here
SCRIPT=${0##*/}

image_name=""
image_version=""
image_tag=""
image_home=""
chart_name=""
chart_version=""
chart_home=""

# process the input args
# For keyword-value arguments the arg gets the keyword and
# the case statement assigns the value to a script variable.
# If any "switch" args are added to the command line args,
# then it wouldn't need a shift after processing the switch
# keyword.  The script variable for a switch argument would
# be initialized to "false" or the empty string and if the
# switch is provided on the command line it would be assigned
# "true".
#
while (( $# > 0 )); do
  arg=$1
  case $arg in
    -h|--help ) usage; exit
                ;;

    -image-name|--image-name) image_name=$2; shift
                ;;

    -image-version|--image-version) image_version=$2; shift
                ;;

    -tag|--tag|-image-tag|--image-tag) image_tag=$2; shift
                ;;

    -image-home|--image-home) image_home=$2; shift
                ;;

    -chart-name|--chart-name) chart_name=$2; shift
                ;;

    -version|--version|-chart-version|--chart-version) chart_version=$2; shift
                ;;

    -chart-home|--chart-home) chart_home=$2; shift
                ;;

    * ) usage;
        info $LINENO "ERROR: Unknown option: $arg in command line."
        exit 1
                ;;
  esac
  # shift to next key-value pair
  shift
done


info $LINENO "BEGIN Build PPA archive."

if [ -z "$image_tag" ]; then
  image_tag=latest
fi

mkdir ppa_archive
mkdir -p ppa_archive/images
mkdir -p ppa_archive/charts

if [ -f ${chart_home}/${chart_name}-chart-${chart_version}.tgz ]; then
  echo "Copying chart from ${chart_home}/${chart_name}-chart-${chart_version}.tgz to charts/ ..."
  cp ${chart_home}/${chart_name}-chart-${chart_version}.tgz ppa_archive/charts/
else
  info $LINENO "ERROR: ${chart_home}/${chart_name}-chart-${chart_version}.tgz file does not exist."
  exit 2
fi

if [ -f ${image_home}/${image_name}-image-${image_version}.tgz ]; then
  echo "Copying image from ${image_home}/${image_name}-image-${image_version}.tgz to images/ ..."
  cp ${image_home}/${image_name}-image-${image_version}.tgz ppa_archive/images/
else
  info $LINENO "ERROR: ${image_home}/${image_name}-image-${image_version}.tgz file does not exist."
  exit 3
fi


info $LINENO "Updating manifest.json with chart version, image version and tag ..."
sed -e 's/__CHART-VERSION__/'${chart_version}'/' \
    -e 's/__IMAGE-TAG__/'${image_tag}'/' \
    -e 's/__IMAGE-VERSION__/'${image_version}'/' manifest.json.tmpl > ppa_archive/manifest.json

info $LINENO "Updating manifest.yaml with chart version and image tag ..."
sed -e 's/__CHART-VERSION__/'${chart_version}'/' \
    -e 's/__IMAGE-TAG__/'${image_tag}'/' manifest.yaml.tmpl > ppa_archive/manifest.yaml


echo "Building ${chart_name}-ppa-${chart_version}.tgz ..."
tar -C ./ppa_archive -czvf ${chart_name}-ppa-${chart_version}.tgz images charts manifest.json manifest.yaml

rm -rf ./ppa_archive

info $LINENO "END build PPA archive."
