import XCTest
@testable import dimmi

final class SettingsFunctionalTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "com.frase.app.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testCooldownZeroSurvivesRoundTrip() {
        XCTAssertEqual(
            UserPrefs.selectionCooldown(in: defaults),
            UserPrefs.defaultSelectionCooldown
        )

        UserPrefs.setSelectionCooldown(0, in: defaults)
        XCTAssertEqual(UserPrefs.selectionCooldown(in: defaults), 0)

        UserPrefs.setSelectionCooldown(-3, in: defaults)
        XCTAssertEqual(UserPrefs.selectionCooldown(in: defaults), 0)
    }

    func testSelectionLengthsAreClampedAndRemainAValidClosedRange() {
        XCTAssertEqual(
            UserPrefs.selectionLengths(in: defaults),
            .init(
                minimum: UserPrefs.defaultSelectionMinLength,
                maximum: UserPrefs.defaultSelectionMaxLength
            )
        )

        UserPrefs.setSelectionLengths(minimum: -20, maximum: 9_999, in: defaults)
        XCTAssertEqual(
            UserPrefs.selectionLengths(in: defaults),
            .init(minimum: 1, maximum: 5_000)
        )

        UserPrefs.setSelectionLengths(minimum: 3, maximum: 3, in: defaults)
        XCTAssertEqual(
            UserPrefs.selectionLengths(in: defaults),
            .init(minimum: 3, maximum: 3)
        )
    }

    func testSelectionLengthsRepairAnInvertedPair() {
        UserPrefs.setSelectionLengths(minimum: 4_800, maximum: 25, in: defaults)
        XCTAssertEqual(
            UserPrefs.selectionLengths(in: defaults),
            .init(minimum: 4_800, maximum: 4_800)
        )
    }

    func testProviderAndEngineConfigsRoundTripWithoutCrossContamination() {
        let anthropic = EngineConfig(apiKey: "  anthropic-key  ", model: " claude-test ")
        let openAI = EngineConfig(apiKey: "openai-key", model: "gpt-test")
        let deepSeek = EngineConfig(
            apiKey: "deepseek-key",
            model: "deepseek-test",
            baseURL: "https://example.test/v1/"
        )

        Secrets.setConfig(anthropic, for: .anthropic, defaults: defaults)
        Secrets.setConfig(openAI, for: .openai, defaults: defaults)
        Secrets.setConfig(deepSeek, for: .deepseek, defaults: defaults)
        Secrets.setProvider(.openai, defaults: defaults)

        XCTAssertEqual(Secrets.currentProvider(defaults: defaults), .openai)
        XCTAssertEqual(
            Secrets.storedConfig(for: .anthropic, defaults: defaults),
            EngineConfig(apiKey: "anthropic-key", model: "claude-test")
        )
        XCTAssertEqual(
            Secrets.storedConfig(for: .openai, defaults: defaults),
            openAI
        )
        XCTAssertEqual(
            Secrets.storedConfig(for: .deepseek, defaults: defaults),
            EngineConfig(
                apiKey: "deepseek-key",
                model: "deepseek-test",
                baseURL: "https://example.test/v1/"
            )
        )
    }

    func testEveryProviderConfigurationRoundTripsIndependently() {
        XCTAssertEqual(
            TranslationProvider.allCases.count,
            22,
            "API 设置页应包含 21 家内置厂商和一个自定义兼容接口"
        )

        var expectedConfigs: [TranslationProvider: EngineConfig] = [:]
        for (index, provider) in TranslationProvider.allCases.enumerated() {
            let config = EngineConfig(
                apiKey: "key-\(index)",
                model: "custom-model-\(index)",
                baseURL: provider.supportsCustomBaseURL
                    ? "https://gateway-\(index).example/v1"
                    : ""
            )
            expectedConfigs[provider] = config
            Secrets.setConfig(config, for: provider, defaults: defaults)
        }

        for provider in TranslationProvider.allCases {
            XCTAssertEqual(
                Secrets.storedConfig(for: provider, defaults: defaults),
                expectedConfigs[provider],
                "切换到 \(provider.rawValue) 时不应读到其他厂商的 Key、模型或 Base URL"
            )
        }
    }

    func testEveryProviderPublishesCompleteSettingsMetadata() {
        let providers = TranslationProvider.allCases
        XCTAssertEqual(Set(providers.map(\.storageID)).count, providers.count)
        XCTAssertEqual(providers.filter { !$0.requiresAPIKey }, [.customCompatible])

        for provider in providers {
            XCTAssertFalse(provider.storageID.isEmpty)
            XCTAssertFalse(provider.keyPlaceholder.isEmpty)
            XCTAssertFalse(provider.configurationHint.isEmpty)

            let options = TranslationModelCatalog.options(for: provider)
            if options.isEmpty {
                XCTAssertTrue(provider.defaultModel.isEmpty)
            } else {
                XCTAssertFalse(provider.defaultModel.isEmpty)
                XCTAssertTrue(options.contains { $0.id == provider.defaultModel })
            }

            if provider.supportsCustomBaseURL, !provider.defaultBaseURL.isEmpty {
                let components = URLComponents(string: provider.defaultBaseURL)
                XCTAssertNotNil(components?.scheme)
                XCTAssertEqual(components?.host?.isEmpty, false)
            }
        }
    }

    func testCustomCompatibleProviderIsManualAndAllowsKeylessLocalEndpoints() {
        let provider = TranslationProvider.customCompatible
        XCTAssertTrue(provider.supportsCustomBaseURL)
        XCTAssertFalse(provider.requiresAPIKey)
        XCTAssertTrue(provider.defaultBaseURL.isEmpty)
        XCTAssertTrue(provider.defaultModel.isEmpty)
        XCTAssertTrue(TranslationModelCatalog.options(for: provider).isEmpty)
        XCTAssertNil(TranslationModelCatalog.recommendedOption(for: provider))
        XCTAssertEqual(
            TranslationModelCatalog.selection(for: "local-model", provider: provider),
            .custom
        )
    }

    func testLegacyOpenAIAndDeepSeekStorageKeysRemainReadable() {
        defaults.set("legacy-openai-key", forKey: "dimmi.openai.apiKey")
        defaults.set("legacy-openai-model", forKey: "dimmi.openai.model")
        defaults.set("legacy-deepseek-key", forKey: "dimmi.deepseek.apiKey")
        defaults.set("legacy-deepseek-model", forKey: "dimmi.deepseek.model")
        defaults.set("https://legacy.deepseek.test/v1", forKey: "dimmi.deepseek.baseURL")

        XCTAssertEqual(
            Secrets.storedConfig(for: .openai, defaults: defaults),
            EngineConfig(apiKey: "legacy-openai-key", model: "legacy-openai-model")
        )
        XCTAssertEqual(
            Secrets.storedConfig(for: .deepseek, defaults: defaults),
            EngineConfig(
                apiKey: "legacy-deepseek-key",
                model: "legacy-deepseek-model",
                baseURL: "https://legacy.deepseek.test/v1"
            )
        )
    }

    func testStoredDeepSeekConfigNeverExposesEmbeddedFallback() {
        let stored = Secrets.storedConfig(for: .deepseek, defaults: defaults)
        XCTAssertTrue(stored.apiKey.isEmpty)

        let effective = Secrets.effectiveConfig(draft: stored, for: .deepseek)
        XCTAssertEqual(effective.model, Secrets.defaultDeepSeekModel)
        XCTAssertEqual(effective.baseURL, Secrets.defaultDeepSeekBase)
    }

    func testBaseURLNormalizationHandlesRequestPathAndTrailingSlashes() {
        XCTAssertEqual(
            Secrets.normalizedBaseURL(
                " https://gateway.example/v1/chat/completions/// ",
                for: .deepseek
            ),
            "https://gateway.example/v1"
        )
        XCTAssertEqual(
            Secrets.normalizedBaseURL("", for: .deepseek),
            Secrets.defaultDeepSeekBase
        )
        XCTAssertEqual(
            Secrets.normalizedBaseURL("", for: .openai),
            "https://api.openai.com/v1"
        )
        XCTAssertEqual(Secrets.normalizedBaseURL("ignored", for: .anthropic), "")
    }

    func testProviderRequestPoliciesCoverKnownCompatibilityDifferences() {
        XCTAssertEqual(
            TranslationProvider.openai.tokenLimitParameter.rawValue,
            "max_completion_tokens"
        )
        XCTAssertEqual(
            TranslationProvider.cerebras.tokenLimitParameter.rawValue,
            "max_completion_tokens"
        )
        XCTAssertEqual(TranslationProvider.cohere.instructionRole(model: "command-a"), "developer")
        XCTAssertEqual(TranslationProvider.groq.instructionRole(model: "qwen"), "system")
        XCTAssertFalse(TranslationProvider.customCompatible.requiresAPIKey)
    }

    func testJSONCleanerExtractsAValidObjectFromCompatibleProviderProse() {
        let json = #"{"italian":"A {brace}","colloquial":"ok","topic":"other","note":"quote: \"x\""}"#
        let response = "Intro {not valid JSON}.\nResult:\n\(json)\nDone."
        XCTAssertEqual(TranslationService.stripCodeFence(response), json)
    }

    func testEveryProviderHasAUniqueModelCatalogAndOneRecommendation() {
        for provider in TranslationProvider.allCases {
            let options = TranslationModelCatalog.options(for: provider)

            if options.isEmpty {
                XCTAssertTrue(provider.defaultModel.isEmpty)
                continue
            }

            XCTAssertGreaterThanOrEqual(options.count, 2)
            XCTAssertEqual(Set(options.map(\.id)).count, options.count)
            XCTAssertEqual(options.filter(\.isRecommended).count, 1)
            XCTAssertTrue(
                options.contains { $0.id == Secrets.defaultModel(for: provider) },
                "The app default must always remain selectable for \(provider.rawValue)"
            )
        }
    }

    func testModelCatalogRecognizesPresetsAndPreservesCustomModelIDs() {
        XCTAssertEqual(
            TranslationModelCatalog.selection(
                for: "  gpt-5.6-terra  ",
                provider: .openai
            ),
            .preset("gpt-5.6-terra")
        )
        XCTAssertEqual(
            TranslationModelCatalog.selection(
                for: "vendor-private-translation-model",
                provider: .openai
            ),
            .custom
        )
        XCTAssertEqual(
            TranslationModelCatalog.resolvedModelID(
                selection: .custom,
                customModelID: "  vendor-private-translation-model  ",
                provider: .openai
            ),
            "vendor-private-translation-model"
        )
    }

    func testEmptyModelInputFallsBackToProviderDefault() {
        for provider in TranslationProvider.allCases {
            let expectedSelection: TranslationModelSelection = provider.defaultModel.isEmpty
                ? .custom
                : .preset(provider.defaultModel)
            XCTAssertEqual(
                TranslationModelCatalog.selection(for: "  ", provider: provider),
                expectedSelection
            )
            XCTAssertEqual(
                TranslationModelCatalog.resolvedModelID(
                    selection: .custom,
                    customModelID: "\n",
                    provider: provider
                ),
                provider.defaultModel
            )
        }
    }

    func testDeepSeekCatalogUsesCurrentDefaultWithoutLosingLegacyRecognition() {
        XCTAssertEqual(Secrets.defaultDeepSeekModel, "deepseek-v4-flash")
        XCTAssertTrue(
            TranslationModelCatalog.option(modelID: "deepseek-chat", for: .deepseek)?.isLegacy == true
        )
        XCTAssertTrue(
            TranslationModelCatalog.option(modelID: "deepseek-reasoner", for: .deepseek)?.isLegacy == true
        )
    }

    func testEveryTargetLanguageHasUniqueRequestMetadata() {
        let languages = TargetLanguage.allCases
        XCTAssertEqual(languages.count, 8)
        XCTAssertEqual(Set(languages.map(\.isoCode)).count, languages.count)
        XCTAssertEqual(Set(languages.map(\.nativeName)).count, languages.count)
        XCTAssertTrue(languages.allSatisfy { !$0.englishName.isEmpty && !$0.chipLabel.isEmpty })
    }

    func testPhraseNotePromptAndPayloadFollowSelectedLanguage() {
        for target in TargetLanguage.allCases {
            let prompt = NoteService.buildSystemPrompt(for: target)
            let message = NoteService.buildUserMessage(
                sourceText: "你好",
                translatedText: "translated-\(target.isoCode)",
                target: target
            )

            XCTAssertTrue(prompt.contains(target.rawValue))
            XCTAssertTrue(prompt.contains(target.nativeName))
            XCTAssertTrue(message.contains(target.rawValue))
            XCTAssertTrue(message.contains("translated-\(target.isoCode)"))
        }
    }

    func testNoteCacheIsLanguageScopedAndClearIsDurable() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dimmi-note-cache-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("notes.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let note = PhraseNote(
            hasNote: true,
            kind: .idiom,
            breakdown: "breakdown",
            usage: "usage",
            example: nil
        )
        let cache = NoteCache(fileURL: fileURL)
        await cache.set(
            note,
            sourceText: "你好",
            translatedText: "Ciao",
            target: .italian
        )
        try await Task.sleep(nanoseconds: 650_000_000)

        let reloaded = NoteCache(fileURL: fileURL)
        let italian = await reloaded.get(
            sourceText: "你好",
            translatedText: "Ciao",
            target: .italian
        )
        let french = await reloaded.get(
            sourceText: "你好",
            translatedText: "Ciao",
            target: .french
        )
        XCTAssertEqual(italian, note)
        XCTAssertNil(french)

        let removed = try await reloaded.clear()
        XCTAssertEqual(removed, 1)

        let emptyReload = NoteCache(fileURL: fileURL)
        let remainingCount = await emptyReload.count
        XCTAssertEqual(remainingCount, 0)
    }

    func testErrorCountdownUsesConfiguredDurationBeforeStarting() async {
        await MainActor.run {
            let viewModel = PanelViewModel()
            viewModel.setMaxAutoDismiss(19)
            viewModel.enterFailed(
                sourceText: "test",
                message: "failed",
                direction: .forward,
                target: .italian
            )
            XCTAssertEqual(viewModel.autoDismissSeconds, 19)
            viewModel.dismiss()
        }
    }

    func testAutomaticSelectionNeverMistakesExistingClipboardForFreshSelection() {
        XCTAssertNil(
            TextGrabber.resolvedCopyResult(
                savedString: "old clipboard URL",
                copiedString: "old clipboard URL",
                pasteboardChanged: false,
                fallbackToExistingClipboard: false
            )
        )

        XCTAssertEqual(
            TextGrabber.resolvedCopyResult(
                savedString: "old clipboard URL",
                copiedString: "new selected text",
                pasteboardChanged: true,
                fallbackToExistingClipboard: false
            ),
            "new selected text"
        )

        // 手动快捷键仍允许以用户现有剪贴板作为兜底。
        XCTAssertEqual(
            TextGrabber.resolvedCopyResult(
                savedString: "manually copied text",
                copiedString: nil,
                pasteboardChanged: false,
                fallbackToExistingClipboard: true
            ),
            "manually copied text"
        )
    }

    func testAutomaticCopyPollingCompletesEarlyAndTimesOutSafely() {
        XCTAssertEqual(
            TextGrabber.copyPollingDecision(
                savedString: "old",
                copiedString: "fresh selection",
                pasteboardChanged: true,
                fallbackToExistingClipboard: false,
                attempt: 1
            ),
            .complete("fresh selection")
        )
        XCTAssertEqual(
            TextGrabber.copyPollingDecision(
                savedString: "old",
                copiedString: "old",
                pasteboardChanged: false,
                fallbackToExistingClipboard: false,
                attempt: 1
            ),
            .wait
        )
        XCTAssertEqual(
            TextGrabber.copyPollingDecision(
                savedString: "old",
                copiedString: "old",
                pasteboardChanged: false,
                fallbackToExistingClipboard: false,
                attempt: TextGrabber.copyPollingIntervals.count
            ),
            .complete(nil)
        )
        XCTAssertEqual(
            TextGrabber.copyPollingDecision(
                savedString: "manual clipboard",
                copiedString: nil,
                pasteboardChanged: false,
                fallbackToExistingClipboard: true,
                attempt: TextGrabber.copyPollingIntervals.count
            ),
            .complete("manual clipboard")
        )

        let totalWindow = TextGrabber.copyPollingIntervals.reduce(0, +)
        XCTAssertLessThanOrEqual(TextGrabber.copyPollingIntervals[0], 0.005)
        XCTAssertGreaterThanOrEqual(totalWindow, 0.09)
        XCTAssertLessThanOrEqual(totalWindow, 0.12)
    }

    func testSelectionFastReadDispositionAndCooldown() {
        XCTAssertEqual(
            SelectionMonitor.readDisposition(
                text: "new text",
                baseline: "old text",
                dragDistance: 12,
                clickCount: 1,
                shiftDown: false,
                isRetry: false
            ),
            .accept
        )
        XCTAssertEqual(
            SelectionMonitor.readDisposition(
                text: "same",
                baseline: "same",
                dragDistance: 1,
                clickCount: 1,
                shiftDown: false,
                isRetry: false
            ),
            .ignore
        )
        XCTAssertEqual(
            SelectionMonitor.readDisposition(
                text: "same",
                baseline: "same",
                dragDistance: 12,
                clickCount: 1,
                shiftDown: false,
                isRetry: false
            ),
            .retry
        )
        XCTAssertEqual(
            SelectionMonitor.readDisposition(
                text: "same",
                baseline: "same",
                dragDistance: 12,
                clickCount: 1,
                shiftDown: false,
                isRetry: true
            ),
            .accept
        )

        XCTAssertTrue(
            SelectionMonitor.shouldSuppressForCooldown(
                text: "same",
                previousText: "same",
                elapsed: 0.2,
                cooldown: 1.5
            )
        )
        XCTAssertFalse(
            SelectionMonitor.shouldSuppressForCooldown(
                text: "next sentence",
                previousText: "same",
                elapsed: 0.2,
                cooldown: 1.5
            )
        )
        XCTAssertFalse(
            SelectionMonitor.shouldSuppressForCooldown(
                text: "same",
                previousText: "same",
                elapsed: 2,
                cooldown: 1.5
            )
        )
    }

    func testSelectionMonitoringRouteTracksAuthorizationTransitions() async {
        await MainActor.run {
            XCTAssertEqual(
                AppState.monitoringRoute(
                    autoTranslateEnabled: false,
                    sourceMode: .selection,
                    accessibilityTrusted: true
                ),
                .disabled
            )
            XCTAssertEqual(
                AppState.monitoringRoute(
                    autoTranslateEnabled: true,
                    sourceMode: .clipboard,
                    accessibilityTrusted: true
                ),
                .clipboard
            )
            XCTAssertEqual(
                AppState.monitoringRoute(
                    autoTranslateEnabled: true,
                    sourceMode: .selection,
                    accessibilityTrusted: false
                ),
                .selectionWaitingForAccessibility
            )
            XCTAssertEqual(
                AppState.monitoringRoute(
                    autoTranslateEnabled: true,
                    sourceMode: .selection,
                    accessibilityTrusted: true
                ),
                .selection
            )
        }
    }

    func testAccessibilityAuthorizationMonitorPublishesInitialAndChangedState() async {
        await MainActor.run {
            var trusted = false
            var received: [Bool] = []
            let monitor = AccessibilityAuthorizationMonitor(trustCheck: { trusted })

            monitor.start(interval: 60) { received.append($0) }
            XCTAssertTrue(monitor.isRunning)
            XCTAssertEqual(received, [false])

            // 值不变时不重复通知。
            monitor.refresh()
            XCTAssertEqual(received, [false])

            // 模拟用户在系统设置勾选 dimmi。
            trusted = true
            monitor.refresh()
            XCTAssertEqual(received, [false, true])

            // 撤权同样要立刻下发，让 SelectionMonitor 停止。
            trusted = false
            monitor.refresh()
            XCTAssertEqual(received, [false, true, false])

            monitor.stop()
            XCTAssertFalse(monitor.isRunning)
        }
    }
}
