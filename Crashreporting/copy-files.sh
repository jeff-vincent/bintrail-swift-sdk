#!/bin/bash
set -Eeuo pipefail

cd "$(dirname "$0")"

DIGEST_DIR_NAME=KSCrash.copied

rm -rf $DIGEST_DIR_NAME
mkdir $DIGEST_DIR_NAME


cp KSCrash/Source/KSCrash/Recording/*.* $DIGEST_DIR_NAME
cp KSCrash/Source/KSCrash/Recording/Monitors/*.* $DIGEST_DIR_NAME
cp KSCrash/Source/KSCrash/Recording/Tools/*.* $DIGEST_DIR_NAME
cp KSCrash/Source/KSCrash/llvm/**/*.* $DIGEST_DIR_NAME
cp KSCrash/Source/KSCrash/swift/Basic/*.* $DIGEST_DIR_NAME
cp KSCrash/Source/KSCrash/swift/SwiftStrings.h $DIGEST_DIR_NAME

cp KSCrash/Source/KSCrash/Reporting/Filters/KSCrashReportFilter.* $DIGEST_DIR_NAME
cp KSCrash/Source/KSCrash/Reporting/Filters/KSCrashReportFilterBasic.* $DIGEST_DIR_NAME

cp KSCrash/Source/KSCrash/Reporting/Filters/Tools/* $DIGEST_DIR_NAME

cp KSCrash/Source/KSCrash/Reporting/Filters/KSCrashReportFilterJSON.* $DIGEST_DIR_NAME
cp KSCrash/Source/KSCrash/Reporting/Filters/KSCrashReportFilterGZip.* $DIGEST_DIR_NAME
cp KSCrash/Source/KSCrash/Reporting/Filters/KSCrashReportFilterSets.* $DIGEST_DIR_NAME
cp KSCrash/Source/KSCrash/Reporting/Filters/KSCrashReportFilterAppleFmt.* $DIGEST_DIR_NAME


cat >$DIGEST_DIR_NAME/module.modulemap <<EOL
// WARNING! This file is generated automatically. Don't edit.
module KSCrash {
    header "KSCrash.h"
    export *
}
EOL