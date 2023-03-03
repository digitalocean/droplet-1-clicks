#!/bin/sh


cd /home/
npm install -g express-generator
npm install -g create-react-app
create-react-app mern
cd mern/src
rm App.css App.js logo.svg
mkdir my-test-dir
mv /sample/src/* .