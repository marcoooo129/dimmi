// 注解缓存：键 = "<目标语言 ISO>|<中文>|<目标语言译文>"，值 = PhraseNote。
//
// 落盘到 ~/Library/Application Support/dimmi/notes.json（轻量，几百条不超过 50KB）。
//
// 命中缓存 → 直接返回，跳过 HTTP 请求。
// 写入 → 同时更新内存 + 异步刷盘（不影响主路径延迟）。
//
// 语法注解几乎不会过时，所以不设 TTL。设置页提供"清除缓存"按钮清掉。
import Foundation

actor NoteCache {
    static let shared = NoteCache()

    private struct DiskShape: Codable {
        var version: Int
        var entries: [String: PhraseNote]
    }

    private var entries: [String: PhraseNote] = [:]
    private let fileURL: URL
    private var dirty: Bool = false
    private var flushTask: Task<Void, Never>?

    /// actor init 严格模式下默认 nonisolated；用 isolated 让 disk load 仍在 actor 内串行
    private init() {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory,
                                in: .userDomainMask,
                                appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSHomeDirectory())
                    .appendingPathComponent("Library/Application Support")
        let dir = base.appendingPathComponent("dimmi", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("notes.json")
        // 初始化阶段：磁盘读放在调用点，第一次 shared 访问前不会真去读
        self.entries = [:]
    }

    /// 隔离磁盘位置的内部初始化器，供 XCTest 使用；不会触碰用户生产缓存。
    init(fileURL: URL) {
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        self.fileURL = fileURL
        self.entries = [:]
    }

    /// 第一次访问时同步读盘（actor 内部调用，串行安全）。
    private func loadFromDiskIfNeeded() {
        guard entries.isEmpty, !loadedFromDisk else { return }
        loadedFromDisk = true
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let dec = JSONDecoder()
        if let shape = try? dec.decode(DiskShape.self, from: data) {
            entries = shape.entries
            NSLog("[dimmi][note-cache] loaded \(entries.count) entries from disk")
        }
    }

    private var loadedFromDisk: Bool = false

    // MARK: - 公开 API

    /// 命中即返回 note；未命中返回 nil。
    func get(
        sourceText: String,
        translatedText: String,
        target: TargetLanguage
    ) -> PhraseNote? {
        loadFromDiskIfNeeded()
        let key = Self.key(source: sourceText, translatedText: translatedText, target: target)
        if let note = entries[key] {
            return note
        }

        // v1 缓存没有目标语言字段，当时产品只支持意大利语。
        // 意大利语请求可直接复用旧 key，并在命中时懒迁移到新 key；其他语言绝不
        // 回退旧值，避免相同原文/译文跨语言误命中。无需一次性迁移磁盘文件。
        if target == .italian,
           let legacy = entries[Self.legacyKey(source: sourceText, italian: translatedText)] {
            entries[key] = legacy
            dirty = true
            scheduleFlush()
            return legacy
        }
        return nil
    }

    /// 写入。会异步刷盘（500ms debounce）。
    func set(
        _ note: PhraseNote,
        sourceText: String,
        translatedText: String,
        target: TargetLanguage
    ) {
        loadFromDiskIfNeeded()
        let key = Self.key(source: sourceText, translatedText: translatedText, target: target)
        entries[key] = note
        dirty = true
        scheduleFlush()
    }

    /// 一次性写入多条（命中后跳请求的 fallback 里不会用到，但留着方便测试）。
    func setMany(_ pairs: [(PhraseNote, sourceText: String, translatedText: String, target: TargetLanguage)]) {
        loadFromDiskIfNeeded()
        for p in pairs {
            entries[Self.key(
                source: p.sourceText,
                translatedText: p.translatedText,
                target: p.target
            )] = p.0
        }
        dirty = true
        scheduleFlush()
    }

    /// 旧缓存 API 默认意大利语，供尚未迁移的内部调用与测试保持兼容。
    @available(*, deprecated, message: "Use get(sourceText:translatedText:target:)")
    func get(sourceText: String, italian: String) -> PhraseNote? {
        get(sourceText: sourceText, translatedText: italian, target: .italian)
    }

    @available(*, deprecated, message: "Use set(_:sourceText:translatedText:target:)")
    func set(_ note: PhraseNote, sourceText: String, italian: String) {
        set(note, sourceText: sourceText, translatedText: italian, target: .italian)
    }

    @available(*, deprecated, message: "Use the target-aware setMany overload")
    func setMany(_ pairs: [(PhraseNote, sourceText: String, italian: String)]) {
        setMany(pairs.map { ($0.0, sourceText: $0.sourceText, translatedText: $0.italian, target: .italian) })
    }

    /// 立即清空内存与磁盘缓存，返回被清除的条数。
    /// 设置页可以 `try await` 它并向用户展示真实成功 / 失败，
    /// 不再把“500ms 后可能写盘”当成已清除。
    func clear() throws -> Int {
        loadFromDiskIfNeeded()
        flushTask?.cancel()
        flushTask = nil

        let previousEntries = entries
        let previousDirty = dirty
        let removedCount = entries.count
        entries.removeAll()
        dirty = true
        do {
            try flushNow()
            return removedCount
        } catch {
            // 磁盘未成功清空时回滚内存，避免 UI 以为清掉了，
            // 但重启后旧 notes.json 又全部回来。
            entries = previousEntries
            dirty = previousDirty
            if previousDirty { scheduleFlush() }
            throw error
        }
    }

    /// 调试用：当前条数。
    var count: Int { entries.count }

    // MARK: - 内部

    static func key(source: String, translatedText: String, target: TargetLanguage) -> String {
        // 目标语言必须进入 key：相同原文在法语、日语等语言下的教学注解完全不同。
        "\(target.isoCode)|\(source)|\(translatedText)"
    }

    private static func legacyKey(source: String, italian: String) -> String {
        "\(source)|\(italian)"
    }

    private func scheduleFlush() {
        flushTask?.cancel()
        flushTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
                try await self?.flushNow()
            } catch is CancellationError {
                // debounce 被更新的写入取代，正常结束。
            } catch {
                NSLog("[dimmi][note-cache] flush failed: \(error.localizedDescription)")
            }
        }
    }

    private func flushNow() throws {
        guard dirty else { return }
        let shape = DiskShape(version: 2, entries: entries)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try enc.encode(shape)
        try data.write(to: fileURL, options: .atomic)
        NSLog("[dimmi][note-cache] flushed \(entries.count) entries to disk")
        dirty = false
    }
}
