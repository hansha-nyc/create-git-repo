#!/bin/bash

# Create a new git (directory) repository and initialize the repository.
# Anthony Morales - California

echo "New Git repo will be created and initialized"

read -p "Enter repository name: " REPOSITORY_NAME

if [ ! -d "$REPOSITORY_NAME" ]; then
   mkdir -p "$REPOSITORY_NAME"; git init "$REPOSITORY_NAME"
   echo "Directory $REPOSITORY_NAME was just created."
else
    echo "Directory $REPOSITORY_NAME is already provisioned"
fi

echo "Enjoy building things!"
