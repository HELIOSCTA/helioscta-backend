#!/bin/bash
# Install system dependencies needed by pyodbc
apt-get update && apt-get install -y unixodbc-dev && rm -rf /var/lib/apt/lists/*
