#!/bin/bash

# Start the service
sudo systemctl start javaapp.service

# Check if the service started successfully
if sudo systemctl is-active --quiet javaapp.service; then
    echo "javaapp.service started successfully."
else
    echo "Failed to start javaapp.service."
fi
