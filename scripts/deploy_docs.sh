#!/bin/sh

rm -rf /tmp/authgear-sdk-ios-website
git clone git@github.com:authgear/authgear-sdk-ios.git --branch gh-pages /tmp/authgear-sdk-ios-website
cp -R ./docs/. /tmp/authgear-sdk-ios-website

cd /tmp/authgear-sdk-ios-website

git add .
git commit --allow-empty -m "Deploy documentation"
git push origin gh-pages:gh-pages
