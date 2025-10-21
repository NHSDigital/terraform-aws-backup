#!/bin/bash

set -e

VERSION_FILE_PATH="$1"

# Check if the file path was provided
if [[ -z "$VERSION_FILE_PATH" ]]; then
  echo "🚨 Error: No version file path provided to the script. Usage: $0 <path/to/version/file>"
  exit 1
fi

# 1. Get version from file
if [[ ! -f "$VERSION_FILE_PATH" ]]; then
  echo "🚨 Error: Version file not found at $VERSION_FILE_PATH"
  exit 1
fi

VERSION=$(cat "$VERSION_FILE_PATH")
echo "Version read from file: $VERSION"

# 2. Check version format
# The format must be 'v' followed by three dot-separated numbers (e.g., v1.2.3)
if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "🚨 Error: Version format is invalid. It must be in the format vX.Y.Z (e.g., v1.2.3). Found: $VERSION"
  exit 1
fi
echo "✅ Version format is valid: $VERSION"

# Fetch the latest tag from git history
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
echo "Latest tag found: ${LATEST_TAG:-<None>}" # Display <None> if LATEST_TAG is empty

# --- Comparison Logic ---
IS_GREATER="false" # Default state

# Check 1: No Tags Found
if [[ -z "$LATEST_TAG" ]]; then
  echo "No tags found. Assuming a new project and proceeding with version $VERSION."
  IS_GREATER="true"

# Check 2: Version is the Same as Latest Tag
elif [[ "$VERSION" == "$LATEST_TAG" ]]; then
  echo "🚨 Error: Version $VERSION is the same as the latest tag $LATEST_TAG. The new version must be greater."
  exit 1

# Check 3: Version Comparison
else
  # Split the versions into parts using '.' as the delimiter
  IFS='.' read -r -a VERSION_PARTS <<< "$VERSION"
  IFS='.' read -r -a TAG_PARTS <<< "$LATEST_TAG"

  # Safely extract parts, removing a leading 'v' if present (e.g., v1.2.3 -> 1.2.3)
  VERSION_MAJOR=${VERSION_PARTS[0]#v}
  VERSION_MINOR=${VERSION_PARTS[1]:-0}
  VERSION_PATCH=${VERSION_PARTS[2]:-0}

  TAG_MAJOR=${TAG_PARTS[0]#v}
  TAG_MINOR=${TAG_PARTS[1]:-0}
  TAG_PATCH=${TAG_PARTS[2]:-0}

  # Perform numeric comparison
  if (( VERSION_MAJOR > TAG_MAJOR )) || \
     (( VERSION_MAJOR == TAG_MAJOR && VERSION_MINOR > TAG_MINOR )) || \
     (( VERSION_MAJOR == TAG_MAJOR && VERSION_MINOR == TAG_MINOR && VERSION_PATCH > TAG_PATCH )); then

    echo "✅ Success: Version $VERSION is greater than the latest tag $LATEST_TAG."
    IS_GREATER="true"
  else
    echo "❌ Error: Version $VERSION is not greater than the latest tag $LATEST_TAG."
    exit 1 # FAIL THE JOB HERE
  fi
fi

# Output the key variables for the GitHub Action to consume.
# The 'id: is_greater' step in the workflow will capture these and set them
# as output variables and environment variables.
echo "VERSION=$VERSION"
echo "IS_GREATER=$IS_GREATER"

# Final success exit
exit 0
