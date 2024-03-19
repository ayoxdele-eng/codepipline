#!/bin/bash

# Check if javaapp.service is running
if sudo systemctl is-active --quiet javaapp.service; then
    # Stop the service
    sudo systemctl stop javaapp.service
    echo "javaapp.service stopped."
else
    echo "javaapp.service is not running."
fi
