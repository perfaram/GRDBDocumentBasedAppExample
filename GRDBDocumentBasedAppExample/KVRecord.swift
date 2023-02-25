//
//  KVRecord.swift
//  GRDBDocumentBasedAppExample
//
//  Created by Perceval Faramaz on 22.02.23.
//

import Foundation
import Combine
import GRDB
import GRDBQuery

struct KVRecord: Identifiable, Equatable, Hashable {
    var id = UUID()
    var key: String
    var value: String
}

// MARK: - Persistence
/// Make KVRecord a Codable Record.
///
/// See <https://github.com/groue/GRDB.swift/blob/master/README.md#records>
extension KVRecord: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "records"
    
    // Define database columns from CodingKeys
    fileprivate enum Columns {
        static let id = Column(CodingKeys.id)
        static let key = Column(CodingKeys.key)
        static let value = Column(CodingKeys.value)
    }
}

// MARK: - KVRecord Database Requests
/// Define some KV-record requests used by the application.
///
/// See <https://github.com/groue/GRDB.swift/blob/master/README.md#requests>
/// See <https://github.com/groue/GRDB.swift/blob/master/Documentation/GoodPracticesForDesigningRecordTypes.md>
extension DerivableRequest<KVRecord> {
    /// A request of KV-records ordered by **key** name.
    ///
    /// For example:
    ///
    ///     let records: [KVRecords] = try dbWriter.read { db in
    ///         try KVRecords.all().orderedByKeyName().fetchAll(db)
    ///     }
    func orderedByKeyName() -> Self {
        // Sort by name in a localized case insensitive fashion
        // See https://github.com/groue/GRDB.swift/blob/master/README.md#string-comparison
        order(KVRecord.Columns.key.collating(.localizedCaseInsensitiveCompare))
    }
    
    /// A request of KV-records ordered by the **value**.
    func orderedByValueName() -> Self {
        // Sort by name in a localized case insensitive fashion
        // See https://github.com/groue/GRDB.swift/blob/master/README.md#string-comparison
        order(KVRecord.Columns.value.collating(.localizedCaseInsensitiveCompare))
    }
}

// MARK: - KVRecord querying
/// A Key-Value-record request can be used with the `@Query` property wrapper in order to
/// feed a view with a list of KV-records.
///
/// For example:
///
///     struct MyView: View {
///         @Query(KVRecordRequest(ordering: .byName)) private var records: [KVRecord]
///
///         var body: some View {
///             List(records) { record in ... )
///         }
///     }
struct KVRecordRequest: Queryable {
    enum Ordering {
        case byKeyName
        case byValueName
    }
    
    /// The ordering used by the player request.
    var ordering: Ordering
    
    // MARK: - Queryable Implementation
    
    static var defaultValue: [KVRecord] { [] }
    
    func publisher(in database: DocumentDatabase) -> AnyPublisher<[KVRecord], Error> {
        ValueObservation
            .tracking(fetchValue(_:))
            .publisher(
                in: database.reader,
                // The `.immediate` scheduling feeds the view right on
                // subscription, and avoids an undesired animation when the
                // application starts.
                scheduling: .immediate)
            .eraseToAnyPublisher()
    }
    
    // This method is not required by Queryable, but it makes it easier
    // to test PlayerRequest.
    func fetchValue(_ db: Database) throws -> [KVRecord] {
        switch ordering {
        case .byKeyName:
            return try KVRecord.all().orderedByKeyName().fetchAll(db)
        case .byValueName:
            return try KVRecord.all().orderedByValueName().fetchAll(db)
        }
    }
}
