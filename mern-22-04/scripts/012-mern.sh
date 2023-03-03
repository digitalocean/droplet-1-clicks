#!/bin/sh

cd /home/

# Create express application
npx express-generate mern/server

# Create react application inside of express application
npx create-react-app mern/client

# Copy sample project
cd mern/client/src
mv /sample/src/* .

# Delete sample project
rm -r /sample