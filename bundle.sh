
rm -rf out
mkdir out

rm -rf server/files
mkdir server/files

java -jar bob.jar --archive --platform=x86_64-darwin --archive --liveupdate=yes --bundle-output=out --variant=debug clean build bundle

unzip out/*.zip -d server/files

./out/liveupdatetest.app/Contents/MacOS/liveupdatetest
