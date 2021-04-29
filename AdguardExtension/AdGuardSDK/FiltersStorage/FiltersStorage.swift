
import Foundation

public protocol FiltersStorageProtocol {
    
    func updateFilter(identifier: Int, completion:@escaping (Error?)->Void)
    func updateCustomFilter(identifier: Int, subscriptionUrl: URL, completion:@escaping (Error?)->Void)
    func getFilters(identifiers:[Int])->[Int: String]
    func saveFilter(identifier: Int, content: String)->Error?
}

enum FiltersStorageError: Error {
    case updateError
}

public class FiltersStorage: FiltersStorageProtocol {
    
    let filtersDirectory: String
    
    public init(filtersDirectory: String? = nil) {
        if filtersDirectory == nil {
            let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            let documentDir = urls.first
            self.filtersDirectory = documentDir?.path ?? ""
        }
        else {
            self.filtersDirectory = filtersDirectory!
        }
    }
    
    public func updateFilter(identifier: Int, completion:@escaping (Error?)->Void) {
        
        guard let url = urlForFilter(identifier) else {
            Logger.logError("FiltersStorage downloadFilter - can not generate url for filter with id: \(identifier)")
            completion(FiltersStorageError.updateError)
            return
        }
        
        downloadFilter(url: url, identifier: identifier, completion: completion)
    }
    
    public func updateCustomFilter(identifier: Int, subscriptionUrl: URL, completion: @escaping (Error?) -> Void) {
        downloadFilter(url: subscriptionUrl, identifier: identifier, completion: completion)
    }
    
    public func getFilters(identifiers:[Int])->[Int: String] {
        var result = [Int: String]()
        for id in identifiers {
            guard let fileUrl = fileUrlForFilter(id) else {
                Logger.logError("FiltersStorage getFilters error. Can not generate url for filter with id: \(id)")
                continue
            }
            guard let content = try? String.init(contentsOf: fileUrl, encoding: .utf8) else {
                Logger.logError("FiltersStorage getFilters error. Can not read filter with url: \(fileUrl)")
                
                // try to get presaved filter file
                if  let defaulUrl = defaultFileUrlForFilter(id),
                    let content = try? String.init(contentsOf: defaulUrl, encoding: .utf8) {
                    Logger.logInfo("FiltersStorage return default filter")
                    result[id] = content
                }
                continue
            }
            result[id] = content
        }
        return result
    }
    
    public func saveFilter(identifier: Int, content: String) -> Error? {
        guard let url = fileUrlForFilter(identifier) else { return NSError(domain: "com.adguard.FiltersStorage", code: 0, userInfo: nil)}
        
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        }
        catch {
            return error
        }
        
        return nil
    }
    
    // MARK: - private methods
    
    private func downloadFilter(url: URL, identifier: Int, completion: @escaping (Error?) -> Void) {
        
        guard let saveUrl = fileUrlForFilter(identifier) else {
            Logger.logError("FiltersStorage downloadFilter - can not generate file url for filter with id: \(identifier)")
            completion(FiltersStorageError.updateError)
            return
        }
        
        DispatchQueue(label: "download filter").async {
            do {
                let content = try String(contentsOf: url)
                try content.write(to: saveUrl, atomically: true, encoding: .utf8)
                completion(nil)
            }
            catch {
                Logger.logError("FiltersStorage downloadFilter - download error: \(error)")
                completion(error)
            }
        }
    }
    
    private func urlForFilter(_ identifier: Int)->URL? {
        let url = "https://filters.adtidy.org/ios/filters/\(identifier)_optimized.txt"
        return URL(string: url)
    }
    
    private func fileUrlForFilter(_ identifier: Int)->URL? {
        let dirUrl = URL(fileURLWithPath: filtersDirectory)
        let fileUrl = dirUrl.appendingPathComponent("\(identifier).txt")
        return fileUrl
    }
    
    private func defaultFileUrlForFilter(_ identifier: Int)->URL? {
        return Bundle.main.url(forResource: "\(identifier)", withExtension: "txt")
    }
}
