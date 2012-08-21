#!/bin/sh

if [ "x$1" == "x" ]; then 
	Releaseiphoneos=`pwd`"/Release-iphoneos"
	Releaseiphonesimulator=`pwd`"/Release-iphonesimulator"
	output=`pwd`"/Release-lipo"
else
	Releaseiphoneos="$1/Release-iphoneos"
	Releaseiphonesimulator="$1/Release-iphonesimulator"
	if [ "x$2" == "x" ]; then 
		output="$1/Release-lipo"
	else
		output="$2"
	fi
fi
echo $Releaseiphoneos "+" $Releaseiphonesimulator ">>" $output
if [ ! -d "$output" ]; then
	echo mkdir $output
	mkdir $output
fi

filelist=`ls $Releaseiphoneos/*.a`

for name in $filelist; do
	filename=`basename $name`
	if [ -f "$Releaseiphonesimulator/$filename" ]; then
		echo found $filename
		lipo -create "$Releaseiphoneos/$filename" "$Releaseiphonesimulator/$filename" -output "$output/$filename"
	fi
done