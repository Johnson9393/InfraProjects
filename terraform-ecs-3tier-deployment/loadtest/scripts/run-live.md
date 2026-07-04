# ------------------------------------------------------------------------------
# Shebang
# ------------------------------------------------------------------------------
# Tell the operating system to execute this script using Bash.
#
# Why not use '#!/bin/bash'?
#
# '/usr/bin/env' searches the current user's PATH and finds the correct Bash
# executable automatically.
#
# This makes the script portable across:
# - macOS (Apple Silicon & Intel)
# - Ubuntu
# - Amazon Linux
# - RHEL
# - Custom installations where Bash isn't located at /bin/bash.
#
# Production DevOps projects generally prefer this approach.

<!-- Simple way to remember
#!/bin/bash → "Use this exact Bash."
#!/usr/bin/env bash → "Find the user's preferred Bash from their PATH and use that." -->

#!/usr/bin/env bash


# ------------------------------------------------------------------------------
# Enable Bash Strict Mode
# ------------------------------------------------------------------------------
#
# -e
# Exit immediately if any command fails.
#
# Example:
#   aws s3 cp file.txt s3://bucket
#   terraform apply
#
# If the S3 upload fails, Terraform will never execute.
#
#
# -u
# Treat undefined variables as errors.
#
# Example:
#   echo $USERNAME
#
# If USERNAME doesn't exist,
# the script exits immediately instead of continuing with an empty value.
#
#
# -o pipefail
#
# Consider pipelines.
#
# Example:
#
#   cat file.txt | grep docker | wc -l
#
# Normally Bash returns only the exit status of the last command (wc).
#
# With pipefail enabled,
# if cat or grep fails,
# the entire pipeline fails.
#
#
# Together these three options make shell scripts much safer
# and are considered DevOps best practice.

<!-- set -euo pipefail means:

-e → Stop immediately if any command fails.
-u → Stop if an undefined variable is used.
pipefail → If any command in a pipeline (|) fails, treat the whole pipeline as failed. -->

set -euo pipefail


# ------------------------------------------------------------------------------
# Example Command
# ------------------------------------------------------------------------------
#
# Example of overriding environment variables before executing the script.
#
# VUS=200 \
# VUS_START=60 \
# VUS_STATS=40 \
# DURATION=10m \
# ./run-live.sh constant
#
# These values become environment variables only for this execution.
#
# Very common in:
# - Docker
# - Kubernetes
# - Terraform
# - GitHub Actions
# - CI/CD Pipelines
#
# Example:
#
# AWS_REGION=us-east-1 terraform apply
#
# AWS_PROFILE=dev aws s3 ls
#
# JAVA_HOME=/usr/lib/jvm/java-21 mvn clean install
#
# No code changes required.
# Just override variables while executing.
# ------------------------------------------------------------------------------



# ------------------------------------------------------------------------------
# ROOT_DIR
# ------------------------------------------------------------------------------
#
# Determine the absolute directory where THIS script exists.
#
# This allows the script to work from anywhere.
#
# Example
#
# Folder Structure
#
# project/
# ├── app/
# ├── loadtest/
# │   └── run-local.sh
#
#
# Even if you execute:
#
# cd ~
# /Users/johnson/project/loadtest/run-local.sh
#
# ROOT_DIR still becomes
#
# /Users/johnson/project/loadtest
#
#
# Let's understand the syntax.
#
# ${BASH_SOURCE[0]}
#
# Current script filename.
#
# dirname
#
# Removes the filename.
#
# Example
#
# /Users/johnson/project/loadtest/run-local.sh
#
# becomes
#
# /Users/johnson/project/loadtest
#
#
# cd
#
# Change into that directory.
#
#
# pwd
#
# Print the absolute directory.
#
#
# $(...)
#
# Command Substitution.
#
# Execute everything inside
# and assign its output.
#
#
# Final Result
#
# ROOT_DIR="/Users/johnson/project/loadtest"
#
# This is one of the most common Bash patterns used in production scripts.
# ------------------------------------------------------------------------------

# "Find the directory where this script is stored, convert it into an absolute path, and save it in ROOT_DIR."
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


# ------------------------------------------------------------------------------
# APP_DIR
# ------------------------------------------------------------------------------
#
# Build another path relative to ROOT_DIR.
#
# ${VAR}
#
# Reads an existing variable.
#
# Here
#
# ROOT_DIR=/Users/johnson/project/loadtest
#
# becomes
#
# APP_DIR=/Users/johnson/project/app
#
#
# Notice
#
# We never hardcode absolute paths.
#
# Everything is calculated dynamically.
#
# This makes scripts portable across different machines.
# ------------------------------------------------------------------------------
APP_DIR="${ROOT_DIR}/../app"


# ------------------------------------------------------------------------------
# SCRIPT
# ------------------------------------------------------------------------------
#
# $1
#
# First command-line argument.
#
# Example
#
# ./run-local.sh smoke
#
# $1
#
# smoke
#
#
# ${1:-smoke}
#
# Means
#
# If $1 exists,
# use it.
#
# Otherwise
#
# use "smoke".
#
#
# Example
#
# ./run-local.sh load
#
# SCRIPT=load
#
#
# ./run-local.sh
#
# SCRIPT=smoke
#
# This is called
#
# Parameter Expansion
#
# and is one of the most frequently used Bash features.
# ------------------------------------------------------------------------------
SCRIPT="${1:-smoke}"


# ------------------------------------------------------------------------------
# BASE_URL
# ------------------------------------------------------------------------------
#
# Read BASE_URL from the environment.
#
# If not supplied,
# use localhost.
#
# Example
#
# BASE_URL=http://localhost:9000 ./run-local.sh load
#
#
# Otherwise
#
# BASE_URL=http://localhost:8000
#
# This technique allows one script
# to run against multiple environments
# without changing the code.
# ------------------------------------------------------------------------------
BASE_URL="${BASE_URL:-http://localhost:8000}"


# ------------------------------------------------------------------------------
# TOPIC
# ------------------------------------------------------------------------------
#
# Same concept.
#
# Read TOPIC from the environment.
#
# Default to
#
# docker
#
# if nothing is supplied.
#
# Example
#
# TOPIC=aws ./run-local.sh load
#
# TOPIC=kubernetes ./run-local.sh stress
# ------------------------------------------------------------------------------
TOPIC="${TOPIC:-docker}"


# ------------------------------------------------------------------------------
# usage() Function
# ------------------------------------------------------------------------------

# A Bash function is similar to a method/function in Java, Python or C.
#
# Java
#
# public void usage() {
#     ...
# }
#
# Bash
#
# usage() {
#     ...
# }
#
# Nothing inside this function executes automatically.
#
# It executes only when someone calls:
#
# usage
#
# This function is generally used to display:
#
# • How to execute the script
# • Available command-line arguments
# • Environment variables
# • Examples
#
# This is a very common practice in production shell scripts.


usage() {

  # --------------------------------------------------------------------------
  # cat <<EOF
  # --------------------------------------------------------------------------
  #
  # This is called a Here Document (Heredoc).
  #
  # It prints multiple lines to the terminal exactly as they are written.
  #
  # Think of it like:
  #
  # Java
  #
  # System.out.println("""
  # Usage...
  # Example...
  # """);
  #
  # Everything between
  #
  # <<EOF
  #
  # and
  #
  # EOF
  #
  # is printed to the console.
  #
  # Nothing inside this block is executed as Bash commands.
  #
  cat <<EOF


Usage: $(basename "$0") [smoke|load|stress|frontend]


  # --------------------------------------------------------------------------
  # basename
  # --------------------------------------------------------------------------
  #
  # basename returns only the filename.
  #
  # Example
  #
  # Full Path
  #
  # /Users/johnson/project/loadtest/run-local.sh
  #
  # basename returns
  #
  # run-local.sh
  #
  # Why?
  #
  # Instead of printing a long absolute path,
  # the help menu becomes cleaner.
  #
  # Example Output
  #
  # Usage: run-local.sh smoke
  #
  # instead of
  #
  # Usage:
  # /Users/johnson/project/loadtest/run-local.sh smoke
  #


Runs k6 load tests against the local compose stack.


  # --------------------------------------------------------------------------
  # Help Text
  # --------------------------------------------------------------------------
  #
  # The remaining text is simply documentation shown to the user.
  #
  # It explains:
  #
  # • What this script does
  # • Supported environment variables
  # • Default values
  # • Example commands
  #
  # Nothing here affects script execution.
  #
  # It is only displayed when:
  #
  # usage
  #
  # is called.


Environment variables:

  BASE_URL
      Backend URL.
      Default: http://localhost:8000

  FRONTEND_URL
      Frontend URL.
      Default: http://localhost:3000

  TOPIC
      Quiz topic to test.
      Default: docker

  PLAYER_PREFIX
      Prefix used while generating leaderboard usernames.
      Default: loadtest


Examples:

  $(basename "$0") smoke

  $(basename "$0") load

  BASE_URL=http://localhost:8000 \
  TOPIC=kubernetes \
  $(basename "$0") stress


  # --------------------------------------------------------------------------
  # EOF
  # --------------------------------------------------------------------------
  #
  # EOF marks the end of the Here Document.
  #
  # Once Bash reaches EOF,
  # it stops printing and exits the cat command.
  #
EOF
}



# ------------------------------------------------------------------------------
# ensure_app_running() Function
# ------------------------------------------------------------------------------

# Purpose
#
# Before starting the load test,
# verify that the backend application is running.
#
# If the backend is not running,
# stop the script immediately.
#
# This prevents unnecessary test failures.
#
# Similar to a "pre-check" before executing the actual work.
#
# ------------------------------------------------------------------------------

ensure_app_running() {

  # --------------------------------------------------------------------------
  # Check whether BASE_URL points to localhost.
  #
  # [[ ... ]]
  # is Bash's conditional expression.
  #
  # || means OR.
  #
  # Meaning:
  #
  # If BASE_URL starts with
  #
  # http://localhost:
  #
  # OR
  #
  # https://localhost:
  #
  # then perform a health check.
  #
  # Example
  #
  # BASE_URL=http://localhost:8000   ✅ Check backend
  #
  # BASE_URL=https://localhost:8443  ✅ Check backend
  #
  # BASE_URL=https://dojo.infralabx.space ❌ Skip this check
  #
  # Why?
  #
  # For LIVE environments,
  # another script (run-live.sh) already performs its own checks.
  # This function is mainly for LOCAL Docker Compose testing.
  # --------------------------------------------------------------------------

  if [[ "${BASE_URL}" == http://localhost:* ]] || [[ "${BASE_URL}" == https://localhost:* ]]; then


    # ------------------------------------------------------------------------
    # curl
    #
    # Sends an HTTP request to the backend health endpoint.
    #
    # Example
    #
    # GET http://localhost:8000/health
    #
    # -s
    # Silent mode (hide download progress).
    #
    # -f
    # Fail if HTTP status is 4xx or 5xx.
    #
    # >/dev/null
    #
    # Ignore the response body.
    #
    # We don't care about the JSON response.
    # We only care whether the endpoint is reachable.
    #
    # !
    #
    # Means NOT.
    #
    # So this condition becomes:
    #
    # "If the health endpoint FAILED..."
    # ------------------------------------------------------------------------

    if ! curl -sf "${BASE_URL}/health" >/dev/null; then


      # ----------------------------------------------------------------------
      # Print helpful error messages.
      #
      # echo simply prints text to the terminal.
      # ----------------------------------------------------------------------

      echo "Backend is not reachable at ${BASE_URL}"

      echo "Start the app first:"

      echo "  cd ${APP_DIR} && docker compose up --build -d"


      # ----------------------------------------------------------------------
      # exit 1
      #
      # Stop the entire shell script.
      #
      # Exit Code
      #
      # 0 → Success
      # 1 → Failure
      #
      # Since the backend is unavailable,
      # there is no point continuing the load test.
      # ----------------------------------------------------------------------

      exit 1

    fi
  fi
}


# ------------------------------------------------------------------------------
# Function Parameters vs Script Parameters
# ------------------------------------------------------------------------------

# This is one of the most important Bash concepts.
#
# There are TWO different '$1' variables.
#
# They belong to different scopes.
#
# ------------------------------------------------------------------------------
# 1. Script Argument ($1)
# ------------------------------------------------------------------------------
#
# When executing the shell script:
#
# ./run-local.sh smoke
#
# Here,
#
# Script $1 = smoke
#
# This line stores it into SCRIPT.
#
# SCRIPT="${1:-smoke}"
#
# Result
#
# SCRIPT=smoke
#
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# 2. Function Argument ($1)
# ------------------------------------------------------------------------------
#
# Later, the script executes:
#
# run_with_k6 smoke.js
#
# Here,
#
# smoke.js is NOT the script argument.
#
# It is the FIRST ARGUMENT passed to the function.
#
# Therefore,
#
# Inside run_with_k6()
#
# $1 = smoke.js
#
# Then
#
# local script_file="$1"
#
# becomes
#
# script_file="smoke.js"
#
# This is exactly the same as Java:
#
# runWithK6("smoke.js");
#
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# Complete Execution Flow
# ------------------------------------------------------------------------------
#
# User executes
#
# ./run-local.sh smoke
#
#               │
#               ▼
#
# Script $1 = smoke
#
#               │
#               ▼
#
# SCRIPT=smoke
#
#               │
#               ▼
#
# case "${SCRIPT}"
#
#               │
#               ▼
#
# smoke)
#     run_with_k6 smoke.js
#
#               │
#               ▼
#
# Function $1 = smoke.js
#
#               │
#               ▼
#
# local script_file="$1"
#
#               │
#               ▼
#
# script_file = smoke.js
#
#               │
#               ▼
#
# k6 run "${ROOT_DIR}/scripts/${script_file}"
#
#               │
#               ▼
#
# Final Command Executed
#
# k6 run /Users/johnson/project/loadtest/scripts/smoke.js
#
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# Key Takeaway
# ------------------------------------------------------------------------------
#
# Script Arguments
#
# Passed while executing the shell script.
#
# Example
#
# ./run-local.sh smoke
#
# $1 = smoke
#
#
# Function Arguments
#
# Passed while calling a function.
#
# Example
#
# run_with_k6 smoke.js
#
# $1 = smoke.js
#
#
# Script arguments and function arguments have separate scopes.
# They do NOT interfere with each other.
#
# This is very similar to method parameters in Java.
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# Function Arguments vs Environment Variables
# ------------------------------------------------------------------------------

# Consider this function call:
#
# BASE_URL="${BASE_URL}" TOPIC="${TOPIC}" run_with_k6 smoke.js
#
# Two different things are happening here.
#
# ------------------------------------------------------------------------------
# 1. Function Argument
# ------------------------------------------------------------------------------
#
# run_with_k6 smoke.js
#
# Here,
#
# smoke.js is the FIRST FUNCTION ARGUMENT.
#
# Inside the function:
#
# local script_file="$1"
#
# becomes
#
# script_file="smoke.js"
#
# After
#
# shift
#
# smoke.js is removed from the function arguments.
#
# "$@" now contains only the remaining function arguments (if any).
#
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# 2. Environment Variables
# ------------------------------------------------------------------------------
#
# BASE_URL and TOPIC are NOT function arguments.
#
# They are Environment Variables.
#
# When k6 starts,
# it automatically inherits all available environment variables.
#
# Therefore, inside smoke.js:
#
# __ENV.BASE_URL
# __ENV.TOPIC
#
# automatically become available.
#
# No explicit parameter passing is required.
#
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# Execution Flow
# ------------------------------------------------------------------------------
#
# BASE_URL + TOPIC
#        │
#        ▼
# Environment Variables
#        │
#        ▼
# run_with_k6 smoke.js
#        │
#        ▼
# k6 run smoke.js
#        │
#        ▼
# k6 inherits Environment Variables
#        │
#        ▼
# smoke.js
#        │
#        ▼
# __ENV.BASE_URL
# __ENV.TOPIC
#
# ------------------------------------------------------------------------------



# ------------------------------------------------------------------------------
# run_with_docker() Function
# ------------------------------------------------------------------------------

# Purpose
#
# If k6 is NOT installed on the local machine,
# run the performance test using the official k6 Docker image.
#
# This removes the dependency of installing k6 locally.
#
# Flow
#
# Local Machine
#       │
#       ▼
# Docker Container (grafana/k6)
#       │
#       ▼
# Execute smoke.js / load.js / stress.js
#
# ------------------------------------------------------------------------------

run_with_docker() {

  # --------------------------------------------------------------------------
  # local script_file="$1"
  #
  # Read the first function argument.
  #
  # Example
  #
  # run_with_docker smoke.js
  #
  # script_file = smoke.js
  #
  # --------------------------------------------------------------------------

  local script_file="$1"


  # --------------------------------------------------------------------------
  # shift
  #
  # Remove the first function argument.
  #
  # Remaining arguments (if any) are available in "$@".
  #
  # This is exactly the same concept as run_with_k6().
  # --------------------------------------------------------------------------

  shift


  # --------------------------------------------------------------------------
  # local docker_base_url="${BASE_URL}"
  #
  # Create a LOCAL COPY of BASE_URL.
  #
  # Why?
  #
  # We are going to modify this value.
  #
  # Instead of changing BASE_URL itself,
  # we create another variable.
  #
  # This avoids accidentally modifying the original variable.
  #
  # Similar to:
  #
  # String dockerBaseUrl = baseUrl;
  #
  # in Java.
  # --------------------------------------------------------------------------

  local docker_base_url="${BASE_URL}"


  # --------------------------------------------------------------------------
  # Check if BASE_URL is localhost.
  #
  # Why?
  #
  # Docker Containers CANNOT access your laptop's localhost.
  #
  # Inside Docker,
  #
  # localhost
  #
  # means
  #
  # "THIS Docker container itself."
  #
  # It does NOT mean your backend container.
  #
  # --------------------------------------------------------------------------

  if [[ "${docker_base_url}" == "http://localhost:8000" ]]; then


      # ----------------------------------------------------------------------
      # Replace localhost with the Docker Compose service name.
      #
      # Docker Compose automatically creates DNS names
      # using service names.
      #
      # backend
      #
      # resolves to the Backend container.
      #
      # Therefore
      #
      # http://localhost:8000
      #
      # becomes
      #
      # http://backend:8000
      #
      # so that k6 can communicate with the backend container.
      #
      # ----------------------------------------------------------------------

      docker_base_url="http://backend:8000"

  fi


 # ------------------------------------------------------------------------------
# run_with_docker() Function
# ------------------------------------------------------------------------------

# Purpose
#
# Execute the k6 performance test inside a temporary Docker container
# when k6 is not installed on the local machine.
#
# This ensures every developer can run the tests without installing k6 locally.
#
# ------------------------------------------------------------------------------

run_with_docker() {

  # --------------------------------------------------------------------------
  # local script_file="$1"
  #
  # Read the first function argument.
  #
  # Example
  #
  # run_with_docker smoke.js
  #
  # script_file = smoke.js
  # --------------------------------------------------------------------------

  local script_file="$1"


  # --------------------------------------------------------------------------
  # shift
  #
  # Remove the first function argument.
  #
  # Remaining arguments (if any) are available through "$@".
  #
  # This is exactly the same behaviour as run_with_k6().
  # --------------------------------------------------------------------------

  shift


  # --------------------------------------------------------------------------
  # local docker_base_url="${BASE_URL}"
  #
  # Create a local copy of BASE_URL.
  #
  # We modify this copy without changing the original BASE_URL variable.
  # --------------------------------------------------------------------------

  local docker_base_url="${BASE_URL}"


  # --------------------------------------------------------------------------
  # Docker containers cannot access the host machine using "localhost".
  #
  # Inside a container:
  #
  # localhost = Current Container
  #
  # Therefore, if BASE_URL points to localhost,
  # replace it with the Docker Compose service name.
  #
  # http://localhost:8000
  #
  # becomes
  #
  # http://backend:8000
  #
  # Docker automatically resolves "backend"
  # to the Backend container using Docker DNS.
  # --------------------------------------------------------------------------

  if [[ "${docker_base_url}" == "http://localhost:8000" ]]; then
      docker_base_url="http://backend:8000"
  fi


  # --------------------------------------------------------------------------
  # docker run
  #
  # Start a temporary Docker container
  # using the official grafana/k6 image.
  # --------------------------------------------------------------------------

  docker run \


  # --------------------------------------------------------------------------
  # --rm
  #
  # Automatically remove the container after execution.
  #
  # Keeps the local machine clean.
  # --------------------------------------------------------------------------

      --rm \


  # --------------------------------------------------------------------------
  # -i
  #
  # Run the container in Interactive Mode.
  #
  # Keeps STDIN open while executing k6.
  # --------------------------------------------------------------------------

      -i \


  # --------------------------------------------------------------------------
  # --network app_default
  #
  # Connect the k6 container to the same Docker Compose network.
  #
  # This allows k6 to communicate with:
  #
  # backend:8000
  # frontend:80
  # database
  #
  # using Docker service names.
  # --------------------------------------------------------------------------

      --network app_default \


  # --------------------------------------------------------------------------
  # -v
  #
  # Mount the local scripts folder into the container.
  #
  # Host
  #
  # loadtest/scripts
  #
  # ↓
  #
  # Container
  #
  # /scripts
  #
  # Now k6 can execute smoke.js, load.js, stress.js
  # from inside the container.
  # --------------------------------------------------------------------------

      -v "${ROOT_DIR}/scripts:/scripts" \


  # --------------------------------------------------------------------------
  # -e
  #
  # Pass Environment Variables into the Docker container.
  #
  # These variables are automatically inherited by k6.
  #
  # Inside JavaScript:
  #
  # __ENV.BASE_URL
  # __ENV.TOPIC
  # __ENV.PLAYER_PREFIX
  #
  # become available automatically.
  # --------------------------------------------------------------------------

      -e BASE_URL="${docker_base_url}" \
      -e FRONTEND_URL="${FRONTEND_URL:-http://frontend:80}" \
      -e TOPIC="${TOPIC}" \
      -e PLAYER_PREFIX="${PLAYER_PREFIX:-loadtest}" \


  # --------------------------------------------------------------------------
  # grafana/k6:latest
  #
  # Official Docker image for k6.
  #
  # Docker creates a temporary container from this image.
  # --------------------------------------------------------------------------

      grafana/k6:latest \


  # --------------------------------------------------------------------------
  # Execute the k6 script inside the Docker container.
  #
  # "$@" passes any additional k6 arguments.
  #
  # Example:
  #
  # --vus 100
  # --duration 5m
  #
  # Final execution:
  #
  # k6 run /scripts/smoke.js
  # --------------------------------------------------------------------------

      run "$@" "/scripts/${script_file}"
}

# ------------------------------------------------------------------------------
# Overall Execution Flow
# ------------------------------------------------------------------------------
#
# k6 Installed?
#
#        │
#   ┌────┴─────┐
#   │          │
#  Yes         No
#   │          │
#   ▼          ▼
# Local k6   Docker Container
#                │
#                ▼
#      Join Docker Network
#                │
#                ▼
#      Mount Performance Scripts
#                │
#                ▼
#      Pass Environment Variables
#                │
#                ▼
#      Execute k6 Script
#                │
#                ▼
#      Remove Container (--rm)
#
# ------------------------------------------------------------------------------
#
# Key Takeaways
#
# • Docker is used only when k6 is unavailable locally.
# • The container joins the existing Docker Compose network.
# • Local performance scripts are mounted into the container.
# • Environment variables are passed using -e.
# • k6 automatically inherits those environment variables.
# • The container is automatically deleted after execution.
#
# This approach provides a clean, portable and dependency-free
# execution environment for all developers and CI/CD pipelines.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Main Execution Flow
# ------------------------------------------------------------------------------

# Unlike Java or Python,
# Bash does NOT have a main() function.
#
# Bash executes the script from top to bottom.
#
# First:
#   • Variables are initialized.
#   • Functions are defined.
#
# Then execution starts from here.
#
# Think of this section as the "main()" method of the script.
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# Step 1 - Pre Validation
# ------------------------------------------------------------------------------

# Execute the pre-check function.
#
# Purpose:
#
# Verify that the backend application is running
# before starting any performance test.
#
# If the backend is unavailable,
# the script exits immediately.
#
# This avoids unnecessary test failures.
# ------------------------------------------------------------------------------

ensure_app_running


# ------------------------------------------------------------------------------
# Step 2 - Decide which performance test to execute.
# ------------------------------------------------------------------------------

# case is Bash's equivalent of Java's switch statement.
#
# Java
#
# switch(script){
#
#   case "smoke":
#
# }
#
# Bash
#
# case "${SCRIPT}" in
#
# ------------------------------------------------------------------------------

case "${SCRIPT}" in


# ------------------------------------------------------------------------------
# Smoke Test
# ------------------------------------------------------------------------------

  smoke)

    # --------------------------------------------------------------------------
    # command -v
    #
    # Check whether the command exists.
    #
    # Here:
    #
    # command -v k6
    #
    # verifies whether k6 is installed locally.
    #
    # >/dev/null
    #
    # Ignore the output.
    #
    # 2>&1
    #
    # Ignore error messages as well.
    #
    # We only care about SUCCESS or FAILURE.
    # --------------------------------------------------------------------------

    if command -v k6 >/dev/null 2>&1; then


        # ----------------------------------------------------------------------
        # k6 is installed.
        #
        # Pass the required environment variables
        # and execute the smoke.js script.
        #
        # BASE_URL and TOPIC become Environment Variables.
        #
        # smoke.js becomes the Function Argument.
        #
        # Inside smoke.js:
        #
        # __ENV.BASE_URL
        # __ENV.TOPIC
        #
        # are automatically available.
        # ----------------------------------------------------------------------

        BASE_URL="${BASE_URL}" \
        TOPIC="${TOPIC}" \
        run_with_k6 smoke.js


    # --------------------------------------------------------------------------
    # k6 is NOT installed.
    #
    # But BASE_URL points to a LIVE environment.
    #
    # Running Docker is not useful here because
    # Docker mode is intended only for LOCAL Docker Compose testing.
    #
    # Therefore,
    # instruct the user to install k6.
    # --------------------------------------------------------------------------

    elif [[ "${BASE_URL}" != http://localhost:* ]]; then

        echo "Install k6 for remote endpoint testing: brew install k6"

        echo "Or use: APP_URL=${BASE_URL} ./run-live.sh smoke"

        exit 1


    # --------------------------------------------------------------------------
    # k6 is NOT installed.
    #
    # BASE_URL is localhost.
    #
    # Execute k6 using Docker.
    #
    # No local installation required.
    # --------------------------------------------------------------------------

    else

        echo "k6 not installed locally; running via Docker..."

        run_with_docker smoke.js

    fi

    ;;


# ------------------------------------------------------------------------------
# Load Test
# ------------------------------------------------------------------------------

# Same logic as Smoke Test.
#
# Difference:
#
# Execute quiz-load.js
#
# ------------------------------------------------------------------------------

  load)

    if command -v k6 >/dev/null 2>&1; then

        BASE_URL="${BASE_URL}" \
        TOPIC="${TOPIC}" \
        run_with_k6 quiz-load.js

    else

        run_with_docker quiz-load.js

    fi

    ;;


# ------------------------------------------------------------------------------
# Stress Test
# ------------------------------------------------------------------------------

# Same execution flow.
#
# Difference:
#
# Execute quiz-stress.js
#
# ------------------------------------------------------------------------------

  stress)

    if command -v k6 >/dev/null 2>&1; then

        BASE_URL="${BASE_URL}" \
        TOPIC="${TOPIC}" \
        run_with_k6 quiz-stress.js

    else

        run_with_docker quiz-stress.js

    fi

    ;;


# ------------------------------------------------------------------------------
# Frontend Test
# ------------------------------------------------------------------------------

# Execute frontend performance tests.
#
# Difference:
#
# Uses FRONTEND_URL
# instead of BASE_URL.
#
# ------------------------------------------------------------------------------

  frontend)

    if command -v k6 >/dev/null 2>&1; then

        FRONTEND_URL="${FRONTEND_URL:-http://localhost:3000}" \
        run_with_k6 frontend-load.js

    else

        FRONTEND_URL="${FRONTEND_URL:-http://frontend:80}" \
        run_with_docker frontend-load.js

    fi

    ;;


# ------------------------------------------------------------------------------
# Help
# ------------------------------------------------------------------------------

# Display usage instructions.
# ------------------------------------------------------------------------------

  -h|--help|help)

    usage

    ;;


# ------------------------------------------------------------------------------
# Default Case
# ------------------------------------------------------------------------------

# User supplied an unsupported command.
#
# Print an error.
#
# Display help.
#
# Exit with failure.
# ------------------------------------------------------------------------------

  *)

    echo "Unknown script: ${SCRIPT}"

    usage

    exit 1

    ;;

esac


# ------------------------------------------------------------------------------
# Overall Execution Flow
# ------------------------------------------------------------------------------

# User
#
# ./run-local.sh smoke
#
#         │
#         ▼
#
# Variables Initialized
#
#         │
#         ▼
#
# Functions Loaded
#
#         │
#         ▼
#
# ensure_app_running()
#
#         │
#         ▼
#
# case "${SCRIPT}"
#
#         │
#         ▼
#
# smoke
#
#         │
#         ▼
#
# Is k6 Installed?
#
#      ┌──────────────┐
#      │              │
#     Yes             No
#      │              │
#      ▼              ▼
#
# run_with_k6()   run_with_docker()
#      │              │
#      └──────┬───────┘
#             ▼
#
# Execute smoke.js
#
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# Standard Streams & Output Redirection
# ------------------------------------------------------------------------------

# Every Linux/Bash command communicates using three standard streams.
#
# ------------------------------------------------------------------------------
# 0 → Standard Input (stdin)
# ------------------------------------------------------------------------------
#
# Used to receive input.
#
# Example:
#
# read NAME
#
# User types:
#
# Johnson
#
# stdin = Johnson
#
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# 1 → Standard Output (stdout)
# ------------------------------------------------------------------------------
#
# Normal output produced by a command.
#
# Example:
#
# echo "Hello"
#
# Output:
#
# Hello
#
# This is stdout.
#
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# 2 → Standard Error (stderr)
# ------------------------------------------------------------------------------
#
# Error messages produced by a command.
#
# Example:
#
# ls abc.txt
#
# Output:
#
# ls: abc.txt: No such file or directory
#
# This is stderr.
#
# ------------------------------------------------------------------------------



# ------------------------------------------------------------------------------
# What is /dev/null ?
# ------------------------------------------------------------------------------
#
# /dev/null is a special Linux device.
#
# Think of it as a Black Hole or Dustbin.
#
# Anything sent to /dev/null is discarded permanently.
#
# Example:
#
# echo "Hello" > /dev/null
#
# Output:
#
# Nothing
#
# "Hello" is thrown away.
#
# Easy way to remember:
#
# /dev/null = Dustbin / Black Hole
#
# ------------------------------------------------------------------------------



# ------------------------------------------------------------------------------
# Output Redirection
# ------------------------------------------------------------------------------
#
# >
#
# Redirect stdout.
#
# Example:
#
# echo "Hello" > output.txt
#
# Instead of printing on the screen,
# "Hello" is written into output.txt.
#
# ------------------------------------------------------------------------------
#
# >/dev/null
#
# Redirect stdout to /dev/null.
#
# Ignore the normal output.
#
# Example:
#
# curl -sf http://localhost:8000/health >/dev/null
#
# The API response is discarded.
#
# The script only checks whether the request succeeded.
#
# ------------------------------------------------------------------------------



# ------------------------------------------------------------------------------
# Error Redirection
# ------------------------------------------------------------------------------
#
# 2>
#
# Redirect stderr.
#
# Example:
#
# ls invalid.txt 2> error.log
#
# Error message is written into error.log.
#
# Nothing appears on the terminal.
#
# ------------------------------------------------------------------------------



# ------------------------------------------------------------------------------
# 2>&1
# ------------------------------------------------------------------------------
#
# Redirect stderr (2)
# to wherever stdout (1) is currently going.
#
# Example:
#
# command -v k6 >/dev/null 2>&1
#
# Step 1
#
# >/dev/null
#
# stdout → /dev/null
#
# Step 2
#
# 2>&1
#
# stderr → same destination as stdout
#
# Therefore
#
# stdout → /dev/null
# stderr → /dev/null
#
# Result:
#
# Nothing is printed on the terminal.
#
# The script silently checks whether k6 exists.
#
# ------------------------------------------------------------------------------



# ------------------------------------------------------------------------------
# Why Production Scripts Use This
# ------------------------------------------------------------------------------
#
# Example:
#
# if command -v terraform >/dev/null 2>&1
#
# We don't care where Terraform is installed.
#
# We only care whether it exists.
#
# Similarly:
#
# if command -v k6 >/dev/null 2>&1
#
# We don't want to print:
#
# /usr/local/bin/k6
#
# or
#
# command not found
#
# We only check:
#
# Installed?
#
# Yes → Continue
#
# No → Execute another logic
#
# This keeps production scripts clean and professional.
#
# ------------------------------------------------------------------------------



# ------------------------------------------------------------------------------
# Quick Revision
# ------------------------------------------------------------------------------
#
# stdin (0)
# → Input to a command.
#
# stdout (1)
# → Normal output.
#
# stderr (2)
# → Error output.
#
# >
# → Redirect stdout.
#
# 2>
# → Redirect stderr.
#
# >/dev/null
# → Ignore normal output.
#
# 2>/dev/null
# → Ignore only errors.
#
# >/dev/null 2>&1
# → Ignore both stdout and stderr.
#
# /dev/null
# → Linux Black Hole / Dustbin.
#
# ------------------------------------------------------------------------------