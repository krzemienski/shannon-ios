#!/bin/bash

# Script to identify and help fix duplicate type definitions

echo "=== Duplicate Type Analysis ==="
echo

# List of types that appear to be duplicated
TYPES=(
    "ConnectionQuality"
    "APIHealth"
    "APIError"
    "ServiceContainer"
    "MetricType"
    "TimeRange"
    "MCPTool"
    "CreateProjectRequest"
    "ModelsResponse"
    "ErrorResponse"
)

for TYPE in "${TYPES[@]}"; do
    echo "Checking $TYPE..."
    grep -r "^[public ]*\(struct\|class\|enum\) $TYPE" Sources/ --include="*.swift" | head -5
    echo "---"
done

echo
echo "=== Summary ==="
echo "Multiple duplicate type definitions found across the codebase."
echo "This needs architectural refactoring to consolidate types."
echo
echo "Recommended approach:"
echo "1. Move all shared types to NetworkModels.swift"
echo "2. Remove local definitions"
echo "3. Update imports where needed"