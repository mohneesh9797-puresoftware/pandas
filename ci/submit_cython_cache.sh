#!/bin/bash

CACHE_File="$HOME/.cache/cython_files.tar"
PYX_CACHE_DIR="$HOME/.cache/pyxfiles"
pyx_file_list=`find ${TRAVIS_BUILD_DIR} -name "*.pyx" -o -name "*.pxd" -o -name "*.pxi.in"`

rm -rf $CACHE_File
rm -rf $PYX_CACHE_DIR

home_dir=$(pwd)

mkdir -p $PYX_CACHE_DIR
rsync -Rv $pyx_file_list $PYX_CACHE_DIR

echo "pyx files:"
echo $pyx_file_list

#tar cf ${CACHE_File} --files-from /dev/null

echo "/dev/null/ "

for i in ${pyx_file_list}
do
        echo $i
        f=${i%.pyx}
        echo " $f.{c,cpp} | tar rf  ${CACHE_File} -T -"
        ls $f.{c,cpp} | tar rf  ${CACHE_File} -T -
        echo $i
done

echo "Cython files in cache tar:"
tar tvf ${CACHE_File}
echo "pallav end " 
exit 0
