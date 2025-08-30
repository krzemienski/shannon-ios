#!/usr/bin/env python3
"""
Fix malformed access modifiers and split keywords in Swift files.
Handles patterns like:
- cpublic reateProject -> public func createProject
- ppublic roject -> let project 
- fpublic ilteredTools -> public var filteredTools
"""

import re
import os
import sys
from pathlib import Path

def fix_malformed_code(content):
    """Fix malformed Swift code patterns."""
    
    # Pattern mappings for common cases
    replacements = [
        # func declarations
        (r'\bfunc\s+cpublic\s+reate', 'public func create'),
        (r'\bfunc\s+epublic\s+dit', 'public func edit'),
        (r'\bfunc\s+spublic\s+ave', 'public func save'),
        (r'\bfunc\s+dpublic\s+elete', 'public func delete'),
        (r'\bfunc\s+spublic\s+et', 'public func set'),
        (r'\bfunc\s+dpublic\s+uplicate', 'public func duplicate'),
        (r'\bfunc\s+opublic\s+pen', 'public func open'),
        (r'\bfunc\s+tpublic\s+est', 'public func test'),
        (r'\bfunc\s+cpublic\s+onnect', 'public func connect'),
        (r'\bfunc\s+dpublic\s+isconnect', 'public func disconnect'),
        (r'\bfunc\s+apublic\s+dd', 'public func add'),
        (r'\bfunc\s+rpublic\s+emove', 'public func remove'),
        (r'\bfunc\s+spublic\s+earch', 'public func search'),
        (r'\bfunc\s+cpublic\s+lear', 'public func clear'),
        
        # var declarations  
        (r'\bvar\s+cpublic\s+ategorized', 'public var categorized'),
        (r'\bvar\s+fpublic\s+iltered', 'public var filtered'),
        (r'\bvar\s+hpublic\s+as', 'public var has'),
        (r'\bvar\s+cpublic\s+an', 'public var can'),
        
        # let declarations
        (r'\blet\s+ppublic\s+roject\b', 'let project'),
        (r'\blet\s+cpublic\s+onfig\b', 'let config'),
        (r'\blet\s+spublic\s+uccess\b', 'let success'),
        (r'\blet\s+dpublic\s+uplicated\b', 'let duplicated'),
        (r'\blet\s+ipublic\s+mpact', 'let impact'),
        
        # Fix split variable/function names (generic patterns)
        (r'cpublic\s+reate', 'create'),
        (r'epublic\s+dit', 'edit'), 
        (r'spublic\s+ave', 'save'),
        (r'dpublic\s+elete', 'delete'),
        (r'spublic\s+et', 'set'),
        (r'dpublic\s+uplicate', 'duplicate'),
        (r'opublic\s+pen', 'open'),
        (r'tpublic\s+est', 'test'),
        (r'cpublic\s+onnect', 'connect'),
        (r'dpublic\s+isconnect', 'disconnect'),
        (r'apublic\s+dd', 'add'),
        (r'rpublic\s+emove', 'remove'),
        (r'spublic\s+earch', 'search'),
        (r'cpublic\s+lear', 'clear'),
        (r'cpublic\s+ategorized', 'categorized'),
        (r'fpublic\s+iltered', 'filtered'),
        (r'hpublic\s+as', 'has'),
        (r'cpublic\s+an', 'can'),
        (r'ppublic\s+roject', 'project'),
        (r'cpublic\s+onfig', 'config'),
        (r'spublic\s+uccess', 'success'),
        (r'dpublic\s+uplicated', 'duplicated'),
        (r'ipublic\s+mpact', 'impact'),
    ]
    
    modified = content
    for pattern, replacement in replacements:
        modified = re.sub(pattern, replacement, modified)
    
    return modified

def process_file(filepath):
    """Process a single Swift file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original = content
        modified = fix_malformed_code(content)
        
        if modified != original:
            # Create backup
            backup_path = f"{filepath}.bak"
            with open(backup_path, 'w', encoding='utf-8') as f:
                f.write(original)
            
            # Write fixed content
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(modified)
            
            # Count changes
            changes = len([1 for a, b in zip(original.split('\n'), modified.split('\n')) if a != b])
            print(f"✓ Fixed {filepath} ({changes} lines changed)")
            
            # Remove backup
            os.remove(backup_path)
            return True
        else:
            return False
    except Exception as e:
        print(f"✗ Error processing {filepath}: {e}")
        return False

def main():
    """Main entry point."""
    sources_dir = Path("Sources")
    
    if not sources_dir.exists():
        print("Error: Sources directory not found")
        sys.exit(1)
    
    # Find all Swift files
    swift_files = list(sources_dir.glob("**/*.swift"))
    
    print(f"Scanning {len(swift_files)} Swift files for malformed code...")
    
    fixed_count = 0
    for filepath in swift_files:
        if process_file(filepath):
            fixed_count += 1
    
    print(f"\n✅ Fixed {fixed_count} files")
    
    # Verify no patterns remain
    remaining = []
    for filepath in swift_files:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            if any(pattern in content for pattern in ['cpublic ', 'fpublic ', 'hpublic ', 'ppublic ', 
                                                       'dpublic ', 'epublic ', 'spublic ', 'opublic ',
                                                       'tpublic ', 'apublic ', 'rpublic ', 'ipublic ']):
                remaining.append(filepath)
    
    if remaining:
        print(f"\n⚠️  {len(remaining)} files may still have issues:")
        for f in remaining[:5]:
            print(f"  - {f}")
    else:
        print("✨ All malformed patterns fixed!")

if __name__ == "__main__":
    main()