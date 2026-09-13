import Foundation

struct StopBoardItem: Identifiable, Sendable {
    let routeKey: String
    let entry: RouteEntry
    let etas: [Eta]
    let seq: Int

    var id: String { "\(routeKey)#\(seq)" }
    var upcoming: [Eta] { etas.filter { !$0.eta.isEmpty } }
}

private actor AsyncSemaphore {
    private var permits: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(_ permits: Int) {
        self.permits = permits
    }

    func wait() async {
        if permits > 0 {
            permits -= 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func signal() {
        if waiters.isEmpty {
            permits += 1
        } else {
            waiters.removeFirst().resume()
        }
    }
}

extension ETAService {
    /// Fetches a full departure board for one physical stop.
    static func fetchStopBoard(refs: [StopRouteRef], db: EtaDB, language: AppLanguage, maxRoutes: Int = 40) async -> [StopBoardItem] {
        let limited = Array(refs.prefix(maxRoutes))

        let semaphore = AsyncSemaphore(6)
        var fetched: [StopBoardItem] = []

        await withTaskGroup(of: StopBoardItem?.self) { group in
            for ref in limited {
                guard let entry = db.routeList[ref.routeKey] else { continue }
                group.addTask {
                    await semaphore.wait()
                    var etas = await fetchEtas(entry: entry, seq: ref.seq, db: db, language: language)
                    await semaphore.signal()

                    if entry.co.first == "mtr" {
                        let validNames = Set(entry.stopIDs(.mtr).compactMap { db.stopList[$0]?.name.zh })
                        if !validNames.isEmpty {
                            etas = etas.filter { validNames.contains($0.dest.zh) }
                        }
                    }
                    return StopBoardItem(routeKey: ref.routeKey, entry: entry, etas: etas, seq: ref.seq)
                }
            }
            for await item in group {
                if let item {
                    fetched.append(item)
                }
            }
        }

        return dedupeAndSort(fetched, db: db)
    }

    private static func dedupeAndSort(_ items: [StopBoardItem], db: EtaDB) -> [StopBoardItem] {
        var kept: [StopBoardItem] = []
        var signatures: [String] = []

        for item in items {
            let signature = item.etas.map(\.eta).joined(separator: "|")
            if signature.isEmpty {
                kept.append(item)
                signatures.append(signature)
                continue
            }
            let duplicateIndex = kept.indices.first { index in
                signatures[index] == signature
                    && kept[index].entry.route == item.entry.route
                    && !Set(kept[index].entry.co).isDisjoint(with: Set(item.entry.co))
            }
            if let duplicateIndex {
                if score(item.entry, db: db) < score(kept[duplicateIndex].entry, db: db) {
                    kept[duplicateIndex] = item
                }
            } else {
                kept.append(item)
                signatures.append(signature)
            }
        }

        let isLightRail = kept.contains { $0.entry.co.first == "lightRail" }
        return kept.sorted { lhs, rhs in
            let left = lhs.upcoming
            let right = rhs.upcoming
            if left.isEmpty && right.isEmpty { return lhs.routeKey < rhs.routeKey }
            if left.isEmpty { return false }
            if right.isEmpty { return true }
            if isLightRail {
                let leftRemark = left[0].remark.zh
                let rightRemark = right[0].remark.zh
                if leftRemark != rightRemark { return leftRemark < rightRemark }
                if left[0].eta != right[0].eta { return left[0].eta < right[0].eta }
                return lhs.routeKey < rhs.routeKey
            }
            if left[0].eta == right[0].eta { return lhs.routeKey < rhs.routeKey }
            return left[0].eta < right[0].eta
        }
    }

    private static func score(_ entry: RouteEntry, db: EtaDB) -> Int {
        var score = 0
        if !ServiceHours.isAvailable(entry, db: db) { score += 256 }
        if entry.freq == nil { score += 128 }
        if entry.fares == nil { score += 128 }
        let bounds = Array(entry.bound.values)
        if !bounds.contains("IO") && !bounds.contains("OI") { score += 32 }
        score += Int(entry.serviceTypeValue) ?? 16
        return score
    }
}
