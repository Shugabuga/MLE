#!/bin/bash

CFX="/home/$USER/.firefox-addon-sdk-1.17/bin/cfx"
MCCOY="/home/$USER/.mccoy/mccoy"
CHROME="google-chrome"

PROJECT_URL="http://sebadorn.de/mlp/mle"
ABSOLUTE_PATH="/home/$USER/programming/My Little Emotebox"

export LD_LIBRARY_PATH="/home/$USER/.mccoy/xulrunner/"


function set_version_and_url {
	sed -i "s;%MLE_VERSION%;$VERSION;g" "$1"
	sed -i "s;%MLE_URL%;$PROJECT_URL;g" "$1"
}


function build_opera {
	cd Opera/
	cp config.xml ../config_tmp.xml

	set_version_and_url config.xml
	zip -r ../build/mle.oex *

	mv ../config_tmp.xml config.xml
	cd ../
	cp server/updates-opera-template.xml build/updates-opera.xml

	set_version_and_url build/updates-opera.xml
}


function build_chrome {
	cp Chrome/manifest.json manifest_tmp.json

	set_version_and_url Chrome/manifest.json
	$CHROME --pack-extension="$ABSOLUTE_PATH/Chrome/" --pack-extension-key="$ABSOLUTE_PATH/build/chrome-private-key-mle.pem"

	mv manifest_tmp.json Chrome/manifest.json
	mv Chrome.crx build/mle.crx
	cp server/updates-chrome-template.xml build/updates-chrome.xml

	set_version_and_url build/updates-chrome.xml
}


function build_chrome_store {
	cd Chrome/
	cp manifest.json ../manifest_tmp.json

	set_version_and_url manifest.json
	sed -i "s/\t\"update_url\".*//g" manifest.json
	zip -r ../build/mle-chrome.zip *

	mv ../manifest_tmp.json manifest.json
	cd ../
}


function build_firefox {
	cd Firefox/
	cp package.json ../package_tmp.json

	# Generate addon install file (XPI)
	set_version_and_url package.json
	$CFX xpi --update-url "$PROJECT_URL/updates-firefox.rdf" --force-mobile --output-file="mle-unsigned.xpi"

	# Insert our public key into the generated install.rdf
	unzip "mle-unsigned.xpi" install.rdf
	$MCCOY -installRDF install.rdf -key "My Little Emotebox"
	zip -f "mle-unsigned.xpi" install.rdf
	rm install.rdf

	# Clean up
	mv ../package_tmp.json package.json
	mv "mle-unsigned.xpi" "../build/mle-unsigned.xpi"
	cd ../
}


function build_firefox_updaterdf {
	cp "server/updates-firefox-template.rdf" "build/updates-firefox.rdf"
	local XPI_HASH=$(sha256sum build/mle.xpi | sed "s/ .*//g" -)
	sed -i "s;%XPI_HASH%;sha256:$XPI_HASH;g" "build/updates-firefox.rdf"
	set_version_and_url "build/updates-firefox.rdf"

	# Sign update RDF
	$MCCOY -signRDF "build/updates-firefox.rdf" -key "My Little Emotebox"
	# $MCCOY -verifyRDF "build/updates-firefox.rdf" -key "My Little Emotebox"

	# Replace XPI hash in mle.js
	build_page
}


function build_page {
	local XPI_HASH=$(sha256sum build/mle.xpi | sed "s/ .*//g" -)
	cd server/
	cp "mle-template.js" mle.js
	sed -i "s;%XPI_HASH%;sha256:$XPI_HASH;g" mle.js
	set_version_and_url mle.js
	cd ../
}


if [ $# -ge 1 ] && [ "$1" == "clean" ]; then
	cd build
	rm mle.xpi "mle-unsigned.xpi" mle.crx mle.oex updates-*.xml updates-*.rdf
	cd ../
	exit
fi

if [ $# -lt 2 ]; then
	echo "Not enough arguments provided."
	echo "First argument: all | opera | chrome | chrome_store | firefox | firefox_update | page | clean"
	echo "Second argument: version"
	exit
fi

BROWSER="$1"
VERSION="$2"

if [ "$BROWSER" == "all" ]; then
	build_opera
	build_chrome
	build_chrome_store
	build_firefox
elif [ "$BROWSER" == "opera" ]; then
	build_opera
elif [ "$BROWSER" == "chrome" ]; then
	build_chrome
elif [ "$BROWSER" == "chrome_store" ]; then
	build_chrome_store
elif [ "$BROWSER" == "firefox" ]; then
	build_firefox
elif [ "$BROWSER" == "firefox_update" ]; then
	build_firefox_updaterdf
elif [ "$BROWSER" == "page" ]; then
	build_page
fi

echo " ---------- ---------- ---------- "
echo " Done."
