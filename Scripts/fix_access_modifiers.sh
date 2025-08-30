#!/bin/bash

# Fix malformed access modifiers in Swift files
# Patterns: fpublic, hpublic, cpublic, ppublic -> public

echo "Fixing malformed access modifiers in Swift files..."

# Find all Swift files with malformed modifiers
FILES=$(grep -rl "[fhcp]public\s\+" Sources --include="*.swift")

if [ -z "$FILES" ]; then
    echo "No files with malformed modifiers found."
    exit 0
fi

# Count total occurrences before fix
BEFORE_COUNT=$(grep -rh "[fhcp]public\s\+" Sources --include="*.swift" | wc -l)
echo "Found $BEFORE_COUNT malformed modifiers to fix"

# Process each file
for file in $FILES; do
    echo "Processing: $file"
    
    # Create backup
    cp "$file" "$file.bak"
    
    # Fix patterns - being careful to preserve the spacing after 'public'
    sed -i '' -E 's/([^a-zA-Z])fpublic(\s+)/\1public\2/g' "$file"
    sed -i '' -E 's/([^a-zA-Z])hpublic(\s+)/\1public\2/g' "$file"
    sed -i '' -E 's/([^a-zA-Z])cpublic(\s+)/\1public\2/g' "$file"
    sed -i '' -E 's/([^a-zA-Z])ppublic(\s+)/\1public\2/g' "$file"
    
    # Also handle cases at the start of a line
    sed -i '' -E 's/^fpublic(\s+)/public\1/g' "$file"
    sed -i '' -E 's/^hpublic(\s+)/public\1/g' "$file"
    sed -i '' -E 's/^cpublic(\s+)/public\1/g' "$file"
    sed -i '' -E 's/^ppublic(\s+)/public\1/g' "$file"
    
    # Check if file was modified
    if ! diff -q "$file" "$file.bak" > /dev/null; then
        echo "  ✓ Fixed modifiers in $file"
        rm "$file.bak"
    else
        echo "  - No changes needed in $file"
        rm "$file.bak"
    fi
done

# Count after fix
AFTER_COUNT=$(grep -rh "[fhcp]public\s\+" Sources --include="*.swift" 2>/dev/null | wc -l)
echo ""
echo "✅ Fixed $(($BEFORE_COUNT - $AFTER_COUNT)) malformed modifiers"
echo "Remaining: $AFTER_COUNT"

if [ $AFTER_COUNT -gt 0 ]; then
    echo "⚠️  Some patterns may still need manual review:"
    grep -rn "[fhcp]public\s\+" Sources --include="*.swift" | head -5
fi