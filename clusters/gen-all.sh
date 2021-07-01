rm -rf all-manifest.yaml;
touch all-manifest.yaml;
FILEPATH=$(pwd)/all-manifest.yaml
for folder in `ls`; do
    pushd $folder;
    for file in `ls manifest/*.yaml`; do
        echo "---" >> $FILEPATH;
        cat $file >> $FILEPATH;
        echo "" >> $FILEPATH;
    done
    popd
done
