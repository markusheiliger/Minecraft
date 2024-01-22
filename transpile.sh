#!/bin/bash
clear

for path in $(find ./environments -type f -name main.bicep); do
	pushd $(dirname $path)
	az bicep build --file $(basename $path) --outfile azuredeploy.json
	popd
done

