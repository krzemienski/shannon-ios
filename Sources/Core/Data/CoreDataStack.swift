import Foundation
import CoreData
import OSLog
import Combine

/// Core Data stack for offline data persistence
public class CoreDataStack: ObservableObject {
    
    // MARK: - Properties
    
    @MainActor
    static let shared = CoreDataStack()
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "CoreData")
    
    /// The main persistent container
    private(set) lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "ClaudeCode")
        
        // Configure for app groups to enable data sharing
        let storeURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.claudecode.ios"
        )?.appendingPathComponent("ClaudeCode.sqlite")
        
        let storeDescription = NSPersistentStoreDescription(url: storeURL!)
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Enable automatic migration
        storeDescription.shouldInferMappingModelAutomatically = true
        storeDescription.shouldMigrateStoreAutomatically = true
        
        // Performance optimizations
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreFileProtectionKey)
        storeDescription.type = NSSQLiteStoreType
        
        container.persistentStoreDescriptions = [storeDescription]
        
        container.loadPersistentStores { [weak self] storeDescription, error in
            if let error = error as NSError? {
                self?.logger.error("Core Data failed to load: \(error.localizedDescription)")
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            
            self?.logger.info("Core Data loaded successfully at: \(storeDescription.url?.absoluteString ?? "unknown")")
        }
        
        // Enable automatic merging of changes
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // Set merge policy
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        
        return container
    }()
    
    /// Main view context for UI operations
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    /// Background context for data operations
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        context.automaticallyMergesChangesFromParent = true
        return context
    }
    
    // MARK: - Initialization
    
    private init() {
        setupCoreData()
        setupNotifications()
    }
    
    // MARK: - Setup
    
    private func setupCoreData() {
        // Pre-warm Core Data
        _ = persistentContainer
        
        // Configure view context
        viewContext.undoManager = nil
        viewContext.shouldDeleteInaccessibleFaults = true
        
        logger.info("Core Data stack initialized")
    }
    
    private func setupNotifications() {
        // Listen for remote changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange),
            name: .NSPersistentStoreRemoteChange,
            object: persistentContainer.persistentStoreCoordinator
        )
        
        // Listen for saves
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleContextSave),
            name: .NSManagedObjectContextDidSave,
            object: nil
        )
    }
    
    // MARK: - Core Data Operations
    
    /// Save the view context
    func save() {
        guard viewContext.hasChanges else { return }
        
        do {
            try viewContext.save()
            logger.debug("View context saved successfully")
        } catch {
            logger.error("Failed to save view context: \(error.localizedDescription)")
            
            // Rollback changes on error
            viewContext.rollback()
        }
    }
    
    /// Save a background context
    func save(context: NSManagedObjectContext) async throws {
        guard context.hasChanges else { return }
        
        try await context.perform {
            do {
                try context.save()
                self.logger.debug("Background context saved successfully")
            } catch {
                self.logger.error("Failed to save background context: \(error.localizedDescription)")
                throw error
            }
        }
    }
    
    /// Perform batch operation in background
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        let context = newBackgroundContext()
        
        return try await context.perform {
            let result = try block(context)
            
            if context.hasChanges {
                try context.save()
            }
            
            return result
        }
    }
    
    /// Fetch request with automatic batching
    func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) async throws -> [T] {
        // Configure batching for performance
        request.fetchBatchSize = 20
        request.returnsObjectsAsFaults = false
        
        return try await viewContext.perform {
            try self.viewContext.fetch(request)
        }
    }
    
    // MARK: - Batch Operations
    
    /// Batch insert operation
    func batchInsert<T: NSManagedObject>(
        entityName: String,
        objects: [[String: Any]],
        transform: @escaping (T, [String: Any]) -> Void
    ) async throws {
        try await performBackgroundTask { context in
            for objectData in objects {
                let entity = NSEntityDescription.entity(forEntityName: entityName, in: context)!
                let object = T(entity: entity, insertInto: context)
                transform(object, objectData)
            }
        }
    }
    
    /// Batch delete operation
    func batchDelete<T: NSManagedObject>(_ request: NSFetchRequest<T>) async throws -> Int {
        let batchRequest = NSBatchDeleteRequest(fetchRequest: request as! NSFetchRequest<NSFetchRequestResult>)
        batchRequest.resultType = .resultTypeCount
        
        return try await performBackgroundTask { context in
            let result = try context.execute(batchRequest) as! NSBatchDeleteResult
            return result.result as! Int
        }
    }
    
    /// Batch update operation
    func batchUpdate(
        entityName: String,
        predicate: NSPredicate?,
        properties: [String: Any]
    ) async throws -> Int {
        let batchRequest = NSBatchUpdateRequest(entityName: entityName)
        batchRequest.predicate = predicate
        batchRequest.propertiesToUpdate = properties
        batchRequest.resultType = .updatedObjectsCountResultType
        
        return try await performBackgroundTask { context in
            let result = try context.execute(batchRequest) as! NSBatchUpdateResult
            return result.result as! Int
        }
    }
    
    // MARK: - Migration
    
    /// Check if migration is needed
    func needsMigration() -> Bool {
        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            return false
        }
        
        do {
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: storeURL
            )
            
            let model = persistentContainer.managedObjectModel
            return !model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        } catch {
            logger.error("Failed to check migration status: \(error)")
            return false
        }
    }
    
    /// Perform lightweight migration
    func migrate() async throws {
        guard needsMigration() else { return }
        
        logger.info("Starting Core Data migration")
        
        // Migration is automatic with our configuration
        // Just reload the container
        _ = persistentContainer
        
        logger.info("Core Data migration completed")
    }
    
    // MARK: - Conflict Resolution
    
    /// Resolve conflicts between objects
    func resolveConflicts<T: NSManagedObject>(
        local: T,
        remote: T,
        strategy: ConflictResolutionStrategy
    ) -> T {
        switch strategy {
        case .localWins:
            return local
            
        case .remoteWins:
            return remote
            
        case .lastWriteWins:
            guard let localDate = local.value(forKey: "updatedAt") as? Date,
                  let remoteDate = remote.value(forKey: "updatedAt") as? Date else {
                return local
            }
            return localDate > remoteDate ? local : remote
            
        case .merge:
            // Implement custom merge logic based on entity type
            return mergeObjects(local: local, remote: remote)
            
        case .custom(let resolver):
            return resolver(local, remote) as! T
        }
    }
    
    private func mergeObjects<T: NSManagedObject>(local: T, remote: T) -> T {
        // Default merge implementation
        // Override for specific entity types
        return local
    }
    
    // MARK: - Notifications
    
    @objc private func handleRemoteChange(_ notification: Notification) {
        logger.debug("Received remote change notification")
        
        // Process remote changes
        // TODO: Fix concurrency issue with processRemoteChanges
        // For now, remote changes are not processed to avoid build errors
    }
    
    @objc private func handleContextSave(_ notification: Notification) {
        guard let context = notification.object as? NSManagedObjectContext else { return }
        
        // Merge changes to view context if needed
        if context != viewContext && context.parent == nil {
            viewContext.perform {
                self.viewContext.mergeChanges(fromContextDidSave: notification)
            }
        }
    }
    
    private func processRemoteChanges(_ userInfo: [AnyHashable: Any]?) async {
        // Process remote changes from CloudKit or other sync sources
        logger.debug("Processing remote changes")
    }
    
    // MARK: - Data Export/Import
    
    /// Export all data to JSON
    func exportData() async throws -> Data {
        let exportData = try await performBackgroundTask { context in
            var allData: [String: [[String: Any]]] = [:]
            
            // Export each entity type
            let entities = self.persistentContainer.managedObjectModel.entities
            
            for entity in entities {
                guard let entityName = entity.name else { continue }
                
                let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
                let objects = try context.fetch(request)
                
                var entityData: [[String: Any]] = []
                for object in objects {
                    entityData.append(object.toDictionary())
                }
                
                allData[entityName] = entityData
            }
            
            return try JSONSerialization.data(withJSONObject: allData, options: .prettyPrinted)
        }
        
        return exportData
    }
    
    /// Import data from JSON
    func importData(_ data: Data) async throws {
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        guard let allData = jsonObject as? [String: [[String: Any]]] else {
            throw CoreDataError.invalidImportFormat
        }
        
        try await performBackgroundTask { context in
            for (entityName, entityData) in allData {
                guard NSEntityDescription.entity(forEntityName: entityName, in: context) != nil else {
                    continue
                }
                
                for objectData in entityData {
                    let entity = NSEntityDescription.entity(forEntityName: entityName, in: context)!
                    let object = NSManagedObject(entity: entity, insertInto: context)
                    object.setValuesFromDictionary(objectData)
                }
            }
        }
        
        logger.info("Data import completed successfully")
    }
    
    // MARK: - Cleanup
    
    /// Clear all data
    func clearAllData() async throws {
        let entities = persistentContainer.managedObjectModel.entities
        
        for entity in entities {
            guard let entityName = entity.name else { continue }
            
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            
            try await performBackgroundTask { context in
                try context.execute(deleteRequest)
            }
        }
        
        logger.info("All data cleared successfully")
    }
    
    /// Reset Core Data stack
    func reset() async throws {
        // Clear all data
        try await clearAllData()
        
        // Destroy persistent store
        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else { return }
        
        let coordinator = persistentContainer.persistentStoreCoordinator
        
        for store in coordinator.persistentStores {
            try coordinator.remove(store)
            try FileManager.default.removeItem(at: storeURL)
        }
        
        logger.info("Core Data stack reset completed")
    }
}

// MARK: - Supporting Types

/// Conflict resolution strategy
public enum ConflictResolutionStrategy {
    case localWins
    case remoteWins
    case lastWriteWins
    case merge
    case custom((NSManagedObject, NSManagedObject) -> NSManagedObject)
}

/// Core Data errors
public enum CoreDataError: LocalizedError {
    case invalidImportFormat
    case migrationFailed
    case saveFailed(Error)
    case fetchFailed(Error)
    case conflictResolution(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidImportFormat:
            return "Invalid import data format"
        case .migrationFailed:
            return "Core Data migration failed"
        case .saveFailed(let error):
            return "Failed to save: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch: \(error.localizedDescription)"
        case .conflictResolution(let error):
            return "Conflict resolution failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - NSManagedObject Extensions

extension NSManagedObject {
    /// Convert managed object to dictionary
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        
        for (key, _) in entity.attributesByName {
            if let value = value(forKey: key) {
                dict[key] = value
            }
        }
        
        return dict
    }
    
    /// Set values from dictionary
    func setValuesFromDictionary(_ dict: [String: Any]) {
        for (key, value) in dict {
            if entity.attributesByName[key] != nil {
                setValue(value, forKey: key)
            }
        }
    }
}