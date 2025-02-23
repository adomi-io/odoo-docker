#!/usr/bin/env bash

export TESTS_DATABASE=${TESTS_DATABASE:-"testing"}
export TESTS_ADDONS=${TESTS_ADDONS:-"all"}

# 1. Build the base image
docker build -t testing_image -f ../src/Dockerfile ../src

BUILD_EXIT_CODE=$?

if [ $BUILD_EXIT_CODE -ne 0 ]; then
  echo "Build failed (exit code $BUILD_EXIT_CODE)"
  exit $BUILD_EXIT_CODE
fi

# Start the database
docker run -d \
  --name odoo_testing_db \
  -e POSTGRES_USER="${POSTGRES_USER:-odoo}" \
  -e POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-odoo}" \
  -e POSTGRES_DB="${POSTGRES_DATABASE:-postgres}" \
  postgres:13

while ! docker inspect -f '{{.State.Running}}' odoo_testing_db | grep true > /dev/null; do
  echo "Waiting for odoo_testing_db to be running..."
  sleep 1
done

# 2. Run tests
docker run \
  --name odoo_testing_container \
  --link odoo_testing_db:odoo_testing_db \
  -p 8069:8069 \
  -v "$(pwd)/../src/odoo.conf":/volumes/config/odoo.conf \
  -e ODOO_DB_HOST="${DB_HOST:-odoo_testing_db}" \
  -e ODOO_DB_PORT="${DB_PORT:-5432}" \
  -e ODOO_DB_USER="${DB_USER:-odoo}" \
  -e ODOO_DB_PASSWORD="${DB_PASSWORD:-odoo}" \
  --rm testing_image \
  --database "${TESTS_DATABASE}" \
  --init "${TESTS_ADDONS}" \
  --stop-after-init \
  --workers=0 \
  --max-cron-threads=0 \
  --test-tags='/base:TestRealCursor.test_connection_readonly'

#docker compose \
#  run \
#  --rm odoo -- \
#  --db-host=odoo_testing_db \
#  --database "${TESTS_DATABASE}" \
#  --init "${TESTS_ADDONS}" \
#  --stop-after-init \
#  --workers=0 \
#  --max-cron-threads=0 \
#  --test-tags='/base:TestRealCursor.test_connection_readonly'
##  --test-tags='standard,-/base:TestRealCursor.test_connection_readonly'
##  --test-enable

TEST_EXIT_CODE=$?

# Cleanup our mess
docker stop odoo_testing_db && \
docker rm odoo_testing_db

if [ $TEST_EXIT_CODE -ne 0 ]; then
  echo "Tests failed (exit code $TEST_EXIT_CODE)"
  exit $TEST_EXIT_CODE
fi

echo "All tests passed successfully. ${TEST_EXIT_CODE}"


