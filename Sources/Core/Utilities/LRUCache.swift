//
//  LRUCache.swift
//  ClaudeCode
//
//  Least Recently Used (LRU) cache implementation for memory optimization
//

import Foundation

/// Thread-safe LRU (Least Recently Used) cache implementation
/// Automatically evicts least recently used items when capacity is reached
final class LRUCache<Key: Hashable, Value> {
    
    // MARK: - Node
    private class Node {
        var key: Key
        var value: Value
        var prev: Node?
        var next: Node?
        
        init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }
    }
    
    // MARK: - Properties
    private let maxSize: Int
    private var cache: [Key: Node] = [:]
    private var head: Node?
    private var tail: Node?
    private let queue = DispatchQueue(label: "com.claudecode.lrucache", attributes: .concurrent)
    
    // Metrics
    private(set) var hitCount = 0
    private(set) var missCount = 0
    
    var hitRate: Double {
        let total = hitCount + missCount
        return total > 0 ? Double(hitCount) / Double(total) : 0
    }
    
    var count: Int {
        queue.sync { cache.count }
    }
    
    var isEmpty: Bool {
        queue.sync { cache.isEmpty }
    }
    
    // MARK: - Initialization
    init(maxSize: Int) {
        self.maxSize = max(1, maxSize)
    }
    
    // MARK: - Public Methods
    
    /// Get value for key
    func get(_ key: Key) -> Value? {
        queue.sync(flags: .barrier) {
            guard let node = cache[key] else {
                missCount += 1
                return nil
            }
            
            hitCount += 1
            
            // Move to front (most recently used)
            moveToFront(node)
            
            return node.value
        }
    }
    
    /// Set value for key
    func set(_ key: Key, value: Value) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            if let existingNode = self.cache[key] {
                // Update existing node
                existingNode.value = value
                self.moveToFront(existingNode)
            } else {
                // Create new node
                let newNode = Node(key: key, value: value)
                self.cache[key] = newNode
                self.addToFront(newNode)
                
                // Check capacity
                if self.cache.count > self.maxSize {
                    self.removeLeastRecentlyUsed()
                }
            }
        }
    }
    
    /// Remove value for key
    func remove(_ key: Key) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self,
                  let node = self.cache[key] else { return }
            
            self.removeNode(node)
            self.cache.removeValue(forKey: key)
        }
    }
    
    /// Clear all cached items
    func clear() {
        queue.async(flags: .barrier) { [weak self] in
            self?.cache.removeAll()
            self?.head = nil
            self?.tail = nil
            self?.hitCount = 0
            self?.missCount = 0
        }
    }
    
    /// Check if key exists in cache
    func contains(_ key: Key) -> Bool {
        queue.sync {
            cache[key] != nil
        }
    }
    
    /// Get all keys in cache (ordered by recency)
    func allKeys() -> [Key] {
        queue.sync {
            var keys: [Key] = []
            var current = head
            
            while let node = current {
                keys.append(node.key)
                current = node.next
            }
            
            return keys
        }
    }
    
    // MARK: - Private Methods
    
    private func moveToFront(_ node: Node) {
        guard node !== head else { return }
        
        removeNode(node)
        addToFront(node)
    }
    
    private func addToFront(_ node: Node) {
        node.next = head
        node.prev = nil
        
        head?.prev = node
        head = node
        
        if tail == nil {
            tail = node
        }
    }
    
    private func removeNode(_ node: Node) {
        let prev = node.prev
        let next = node.next
        
        if let prev = prev {
            prev.next = next
        } else {
            // Node is head
            head = next
        }
        
        if let next = next {
            next.prev = prev
        } else {
            // Node is tail
            tail = prev
        }
        
        node.prev = nil
        node.next = nil
    }
    
    private func removeLeastRecentlyUsed() {
        guard let tail = tail else { return }
        
        removeNode(tail)
        cache.removeValue(forKey: tail.key)
    }
}

// MARK: - Subscript Support

extension LRUCache {
    subscript(key: Key) -> Value? {
        get {
            return get(key)
        }
        set {
            if let value = newValue {
                set(key, value: value)
            } else {
                remove(key)
            }
        }
    }
}

// MARK: - CustomStringConvertible

extension LRUCache: CustomStringConvertible {
    var description: String {
        let keys = allKeys()
        return "LRUCache(size: \(count)/\(maxSize), hitRate: \(String(format: "%.2f%%", hitRate * 100)), keys: \(keys))"
    }
}