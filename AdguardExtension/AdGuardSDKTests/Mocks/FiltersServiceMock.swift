import Foundation

final class FiltersServiceMock: FiltersServiceProtocol {
    var groups: [SafariGroup] = []
    
    var updateAllMetaCalled = false
    var updateAllMetaError: Error?
    func updateAllMeta(forcibly: Bool, onFiltersUpdated: @escaping (Error?) -> Void) {
        updateAllMetaCalled = true
        onFiltersUpdated(updateAllMetaError)
    }
    
    var setGroupCalled = false
    var setGroupError: Error?
    func setGroup(withId id: Int, enabled: Bool) throws {
        setGroupCalled = true
        if let error = setGroupError {
            throw error
        }
    }
    
    var setFilterCalled = false
    var setFilterError: Error?
    func setFilter(withId id: Int, _ groupId: Int, enabled: Bool) throws {
        setFilterCalled = true
        if let error = setFilterError {
            throw error
        }
    }
    
    var addCustomFilterCalled = false
    var customFilterError: Error?
    func add(customFilter: ExtendedCustomFilterMetaProtocol, enabled: Bool, _ onFilterAdded: @escaping (Error?) -> Void) {
        addCustomFilterCalled = true
        onFilterAdded(customFilterError)
    }
    
    var deleteCustomFilterCalled = false
    var deleteCustomFilterError: Error?
    func deleteCustomFilter(withId id: Int) throws {
        deleteCustomFilterCalled = true
        if let error = deleteCustomFilterError {
            throw error
        }
    }
    
    var renameCustomFilterCalled = false
    var renameCustomFilterError: Error?
    func renameCustomFilter(withId id: Int, to name: String) throws {
        renameCustomFilterCalled = true
        if let error = renameCustomFilterError {
            throw error
        }
    }
    
    func reset() throws {
        
    }
}
