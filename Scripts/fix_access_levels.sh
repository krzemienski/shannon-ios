#!/bin/bash

echo "Fixing access levels for all Store and ViewModel classes..."

# Function to add public modifiers to a Swift file
fix_access_levels() {
    local file=$1
    echo "Processing: $file"
    
    # Create a temporary file
    temp_file="${file}.tmp"
    
    # Read the file and add public modifiers
    sed -E \
        -e 's/^(final class [A-Za-z]+Store: ObservableObject)/public \1/' \
        -e 's/^(final class [A-Za-z]+ViewModel: ObservableObject)/public \1/' \
        -e 's/^([ ]*@Published var )/\1public /' \
        -e 's/^([ ]*var [a-zA-Z])/\1public /' \
        -e 's/^([ ]*let [a-zA-Z])/\1public /' \
        -e 's/^([ ]*init\()/    public \1/' \
        -e 's/^([ ]*func [a-zA-Z])/\1public /' \
        -e 's/^(struct [A-Za-z]+: )/public \1/' \
        -e 's/^(enum [A-Za-z]+: )/public \1/' \
        -e 's/public public/public/g' \
        "$file" > "$temp_file"
    
    # Replace the original file
    mv "$temp_file" "$file"
}

# Fix Store files
for file in Sources/Core/State/*.swift; do
    if grep -q "final class.*ObservableObject" "$file"; then
        fix_access_levels "$file"
    fi
done

# Fix ViewModel files
for file in Sources/ViewModels/*.swift; do
    if grep -q "final class.*ObservableObject" "$file"; then
        fix_access_levels "$file"
    fi
done

# Fix NetworkMonitor
echo "Fixing NetworkMonitor..."
sed -i '' 's/private init()/public init()/' Sources/Services/NetworkMonitor.swift 2>/dev/null || true

# Fix OfflineQueueManager  
echo "Fixing OfflineQueueManager..."
sed -i '' 's/private init()/public init()/' Sources/Services/OfflineQueueManager.swift 2>/dev/null || true

echo "Access level fixes complete!"