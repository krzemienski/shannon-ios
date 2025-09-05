#!/bin/bash

# Fix UIKit imports for cross-platform compilation

FILES=$(grep -r "import UIKit" /Users/nick/Documents/shannon-ios/Sources/ --include="*.swift" -l)

for file in $FILES; do
    echo "Fixing $file"
    
    # Check if already has conditional compilation
    if grep -q "#if os(iOS)" "$file"; then
        echo "  Already has conditional compilation, skipping"
        continue
    fi
    
    # Add #if os(iOS) before import UIKit
    sed -i '' 's/import UIKit/#if os(iOS)\
import UIKit/' "$file"
    
    # Add #endif at the end of file if not already present
    if ! tail -1 "$file" | grep -q "#endif"; then
        echo "#endif // os(iOS)" >> "$file"
    fi
done

echo "Done fixing UIKit imports"