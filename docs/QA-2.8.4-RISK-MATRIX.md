# NeClip 2.8.4 — risk review matrix

Reviewed 2026-09-21 against baseline `c5e302056160b3d7f0994dad687345ef014d3e4f`.
This is a risk inventory, not 100 discovered bugs or 100 completed physical tests. File line references describe the baseline; names identify test entry points.

The independent review classified68 rows as code-review-only and32 as unverified. Those original labels are retained below rather than converting a passing unit suite into unsupported end-to-end coverage. Release verification is reported separately.

Follow-up fixes cover native Return routing (R001), explicit snippet history (R027), file JSON decoding (R043), draft metadata (R035), queued exclusions (R054), and streamed search (R096). Additional regression tests cover Cmd-Return, title spacing, and protected clipboard provenance across repeated expansions, transition windows and monitor restart. JSON transfer (R039) remains a merge format, not a structural backup; documentation now states that distinction. R083 now has a synthetic asynchronous cancellation/restart regression test: late cancelled work cannot clear the replacement or show stale errors. Physical ScreenCaptureKit, multi-display and Spaces behavior remains unverified; no universal capture guarantee is claimed.

## Матрица — ровно 100 строк

### Меню — 12 сценариев

| ID | Конкретный риск / проверяемый сценарий | Evidence / test name | Статус | Severity |
|---|---|---|---|---|
| R001 | Enter в меню не выполняет выбранное действие; причина StatusBarController принадлежит родителю | parent-owned: StatusBarController Enter; номера строк и доказательство исправления предоставляет родитель | unverified | P2 |
| R002 | На переходе 10→11 элементов первая дополнительная страница теряет элемент 11 | testPaginationKeepsExactRangesAndAbsoluteIndices, fixtures 10/11 | code-review-only | P2 |
| R003 | При 25/100 элементах последняя страница имеет неверные абсолютные индексы или дубли | testPaginationKeepsExactRangesAndAbsoluteIndices, fixtures 25/100 | code-review-only | P2 |
| R004 | Усечение заголовка разрывает семейный emoji или combining mark | testUnicodeGraphemeClustersAreNotSplit | code-review-only | P3 |
| R005 | Строки ровно 32 и 33 символа получают неправильное многоточие | testExactLimitDoesNotAddEllipsis; testOneCharacterPastLimitAddsEllipsisAfterExactlyNCharacters | code-review-only | P3 |
| R006 | Tab/CR/LF/Unicode-разделители ломают однострочное меню | testAllWhitespaceRunsCollapseAndEdgesAreTrimmed | code-review-only | P3 |
| R007 | Dark appearance не распространяется на вложенные меню и custom views | testAppearanceAppliesRecursivelyToSubmenusAndCustomViews | code-review-only | P3 |
| R008 | Изменение snippets во время чтения clips принимает устаревший snapshot | testChangesDuringReadRemainDirtyAndRejectStaleResult | code-review-only | P2 |
| R009 | Завершившееся после erase чтение возвращает удалённые данные в меню | testErasureInvalidatesInFlightReadAndReloadsBothDomains | code-review-only | P1 |
| R010 | Ошибка чтения сбрасывает dirty-флаг, и повторное открытие остаётся устаревшим | testFailureRetainsDirtyWorkAndNewReadSupersedesOldRead | code-review-only | P2 |
| R011 | Уведомление clips заставляет заново читать snippets и наоборот | testIndependentDomainsAvoidUnrelatedReads | code-review-only | P3 |
| R012 | Для 1000 clips × 200 folders меню заранее создаёт весь набор действий | testMenuDefersFolderTargetsUntilTheSpecificActionMenuOpens — только policy-счётчик, не runtime-профиль меню | code-review-only | P2 |

### Клавиатура — 14 сценариев

| ID | Конкретный риск / проверяемый сценарий | Evidence / test name | Статус | Severity |
|---|---|---|---|---|
| R013 | Один owned hotkey вызывает callback дважды или до возврата Carbon handler | testOwnedPressReturnsBeforeExecutingExactlyOnceOnMainQueue | code-review-only | P2 |
| R014 | Чужой hotkey ID/signature или key release запускает команду NeClip | testForeignIdentifiersSignaturesAndReleasesAreNotConsumedOrDispatched | code-review-only | P2 |
| R015 | Неудачная регистрация нового shortcut удаляет старое рабочее сочетание | testUpdateKeepsWorkingShortcutWhenCandidateIsUnavailable | code-review-only | P2 |
| R016 | Одинаковое сочетание назначается двум действиям, включая screenshot/sequential paste | testEveryOtherNeClipActionParticipatesInConflictValidation | code-review-only | P2 |
| R017 | После исчезновения внешнего конфликта то же сочетание невозможно повторно зарегистрировать | testSameCandidateRetriesAfterStartupConflictDisappears | code-review-only | P2 |
| R018 | Сброс одного shortcut меняет другие или теряет рабочий shortcut при занятом default | testSingleShortcutResetPreservesOtherActionsAndRejectsUnavailableDefault | code-review-only | P2 |
| R019 | Частично неудачный общий reset оставляет неполный набор сочетаний | testFailedResetRestoresTheCompletePreviousWorkingSet | code-review-only | P2 |
| R020 | Escape во время записи сочетания сохраняется как новая команда вместо отмены | ShortcutRecorderButton.record, Sources/NeClip/ShortcutRecorder.swift:121 | code-review-only | P2 |
| R021 | Потеря first responder оставляет recorder в режиме перехвата последующих клавиш | ShortcutRecorderButton.resignFirstResponder, Sources/NeClip/ShortcutRecorder.swift:83 | code-review-only | P2 |
| R022 | Standalone Option не выдаёт ровно один trigger на release | testStandaloneOptionReleaseTriggersCorrection; testRepeatedStandaloneReleaseArmsNextGestureWithoutDuplicateTrigger | code-review-only | P2 |
| R023 | Option+ввод/мышь/другой modifier ошибочно воспринимается как standalone Option | testOptionWithTypingDoesNotTrigger; testOptionWithOtherModifierOrMouseDoesNotTrigger | code-review-only | P1 |
| R024 | Перекрытие левого и правого Option заново вооружает уже отменённый жест | testOverlappingOptionKeysCannotRearmCancelledGesture | code-review-only | P1 |
| R025 | Matcher принимает лишний Command/Shift либо ошибочно отвергает shortcut при включённом Caps Lock | testExactMatcherRejectsARecognizedExtraModifierButIgnoresCapsLock | unverified | P2 |
| R026 | На реальной RU/EN-клавиатуре зарегистрированная физическая клавиша перестаёт вызывать команду после смены source | testDisplayAndMenuEquivalentUsePhysicalKeyLabel — только модель; будущий физический smoke в изолированном окружении | unverified | P2 |

### Сниппеты — 16 сценариев

| ID | Конкретный риск / проверяемый сценарий | Evidence / test name | Статус | Severity |
|---|---|---|---|---|
| R027 | Использование сниппета создаёт нежелательную запись истории | parent-owned: PasteService snippet→history; повторный анализ причины исключён | unverified | P1 |
| R028 | Неизвестный, незакрытый или иной регистр placeholder повреждает буквальный шаблон | testLiteralUnknownAndIncompleteTokensArePreserved | code-review-only | P2 |
| R029 | Экранированный {{clipboard}} читает/подставляет clipboard вместо буквального текста | testAllKnownTokensCanBeEscapedWithoutClipboardAccess — проверяет renderer, не вызывающий PasteService | code-review-only | P1 |
| R030 | Clipboard со строкой {date:iso} повторно интерпретируется; два placeholder дают разные значения | testInsertedClipboardIsLiteralAndRepeatedTokensAreStable | code-review-only | P2 |
| R031 | ISO-дата зависит от th_TH/ar_SA календаря или игнорирует явно переданный time zone | testISOUsesExplicitTimeZoneAndGregorianCalendarRegardlessOfLocale | code-review-only | P2 |
| R032 | Соседние placeholders и combining mark съедают окружающий Unicode | testAdjacentTokensAndEscapesDoNotConsumeSurroundingUnicode | code-review-only | P2 |
| R033 | Повторный clipboard placeholder раздувает результат сверх лимита | testAmplifiedClipboardFailsBeforeExceedingOutputLimit | code-review-only | P2 |
| R034 | Лимит по числу символов вместо UTF-8 пропускает emoji сверх byte budget или обрезает строку | testOutputLimitUsesUTF8BytesAndNeverTruncates | code-review-only | P2 |
| R035 | Сохранение dirty content возвращает сниппет в папку до внешнего перемещения | S3; P-S3; testExternalRefreshKeepsDirtyTextAndSelection не проверяет последующий flush | code-review-only | P2 |
| R036 | Ошибка autosave теряет draft и блокирует осмысленный retry | testFailedSaveKeepsRetryStateAndDraftUntilSuccessfulRetry | unverified | P1 |
| R037 | Прямое открытие другого snippetID отбрасывает невалидный текущий draft | testDirectOpenCannotDiscardInvalidDraft | unverified | P1 |
| R038 | Delete → удаление папки → Undo теряет сниппет вместо переноса в «Без папки» | testDeleteUndoRestoresSelectionAndSurvivesDeletedFolder | unverified | P1 |
| R039 | JSON round trip объединяет одноимённые папки/записи и пропускает пустые папки | S2; P-S2; продуктовый контракт полного сохранения структуры не установлен | code-review-only | P2 |
| R040 | Импорт версии будущего формата частично меняет библиотеку до отказа | testUnsupportedVersionIsRejectedBeforeMutation; importSnippetData version guard | code-review-only | P1 |
| R041 | Экспорт >5000 snippets или >16 MiB создаёт файл, который собственный importer отвергнет | testExportRejectsLibraryThatItsOwnImporterCannotReadWithoutDeletingAnything; exportSnippetData size guards | code-review-only | P2 |
| R042 | Повторный импорт одного переносимого файла удваивает snippets | testExportImportPreservesFoldersContentAndPinsWithoutUsageHistory, второй import ожидает 0 | code-review-only | P2 |

### История — 14 сценариев

| ID | Конкретный риск / проверяемый сценарий | Evidence / test name | Статус | Severity |
|---|---|---|---|---|
| R043 | Новая файловая запись с JSON-путями не открывается через «Открыть» | D1; P-D1; resolvesOnlyExplicitSafeOpenTargets использует legacy fixture | code-review-only | P2 |
| R044 | Изменение поискового запроса сохраняет активное действие над старым выделением | testChangingQueryImmediatelyBlocksEveryActionOnOldSelection | unverified | P1 |
| R045 | Erase во время поиска оставляет текст или принимает уже прочитанный старый ответ | testErasureClearsVisibleTextAndRejectsAnAlreadyReadReply | unverified | P1 |
| R046 | Закрытие поиска и новая сессия принимают поздний ответ предыдущей сессии | testProgrammaticCloseRejectsPendingReplyAndNewSessionStillWorks | unverified | P2 |
| R047 | Старое совпадение не находится за новыми несовпадающими строками | testSearchDoesNotHideOlderMatchBehindRecentNonMatches; searchClipSummaries predicate-before-limit | code-review-only | P2 |
| R048 | Исчезнувшее приложение в filter оставляет пустую/необновляемую выдачу | testRemovedApplicationFilterFallsBackToAllApplicationsAndRefreshesResults | unverified | P2 |
| R049 | Повторная plain-copy того же текста оставляет старый RTF в дедуплицированной записи | testHashDedupDropsStaleRTFWhenLatestCopyIsPlainText | unverified | P2 |
| R050 | Неудачная sequential paste продвигает очередь и пропускает текущий элемент | testFailedPasteKeepsCurrentItem | code-review-only | P2 |
| R051 | Внешнее копирование или timeout продолжает старую последовательность вставки | testTimeoutAndExternalCaptureStartAFreshSequence | code-review-only | P2 |
| R052 | Append превышает лимит объединённого текста и теряет новое допустимое копирование | testAppendNextTextFallsBackWithoutMutatingWhenCombinedValueIsTooLarge; processText fallback | code-review-only | P1 |
| R053 | Pause, включённая после постановки capture в очередь, не предотвращает запись | ClipboardMonitor.process/insert pause guards Sources/NeClip/ClipboardMonitor.swift:364 и :512; нужен queued-pause integration test | code-review-only | P1 |
| R054 | Приложение добавлено в exclusions после enqueue, но queued запись сохраняется | S5; P-S5; нет доказательства фактической записи в этом аудите | code-review-only | P1 |
| R055 | Задержанный timer после ухода из excluded app сохраняет её поколение clipboard | testExcludedChangeCountSurvivesDelayedTimerTick; ClipboardExcludedChangeGuard | code-review-only | P1 |
| R056 | Clear history завершается раньше queued insert и удалённая история появляется снова | testQueuedSnapshotFinishesBeforeDeletionWithoutBlockingMainActor | unverified | P1 |

### Раскладка — 14 сценариев

| ID | Конкретный риск / проверяемый сценарий | Evidence / test name | Статус | Severity |
|---|---|---|---|---|
| R057 | Ручной EN→RU / RU→EN использует неверное направление | testManualConversionWorksBothDirections | code-review-only | P2 |
| R058 | Исправление предыдущего слова удаляет запятую, пробелы, CRLF или меняет undo range | testPreviousWordCorrectionPreservesDelimitersPunctuationAndUndoRange | code-review-only | P1 |
| R059 | Truncated AX-window или пустой токен приводит к замене части слова | testPreviousWordTargetRejectsEmptyAndTruncatedTokensAndPreservesExplicitSelection | code-review-only | P1 |
| R060 | Manual conversion портит регистр и хвостовую пунктуацию | testManualConversionPreservesCaseAndLiteralTrailingPunctuation | code-review-only | P2 |
| R061 | Смешанные алфавиты/цифры исправляются без достоверного направления | testManualConversionFailsClosedForMixedScriptsOrNoLetters; отдельно source-aware режим имеет другой контракт | code-review-only | P1 |
| R062 | Автоисправление изменяет известное исходное слово, когда обе формы словарные | testAutoDecisionRequiresOnlyConvertedWordToBeKnown | code-review-only | P1 |
| R063 | Auto correction меняет APIX, myVar, email, path или abc123 | testAutoDecisionRejectsShortAllCapsCodeAndStructuredTokens | code-review-only | P1 |
| R064 | Последний key ещё не виден через AX, и слово навсегда пропускается | testLastKeyNotYetVisibleRetriesThenCorrectsWithoutSpace | code-review-only | P2 |
| R065 | Retry повторяет неоднозначную запись или работает после смены sequence | testRetryIsBoundedAndNeverRepeatsMutationOrStaleKey | code-review-only | P1 |
| R066 | Emoji перед словом смещает UTF-16 caret и портит соседние строки | testMultilineLongDocumentPreservesPrefixSuffixAndUTF16Caret | code-review-only | P1 |
| R067 | Пропущенная первая буква позволяет исправить только совпавший suffix большего слова | testCannotCorrectSuffixAfterMissedLeadingKeyOrExistingSelection | code-review-only | P1 |
| R068 | Между чтением и выделением пользователь меняет текст, который затем затирается | testConcurrentEditBetweenReadAndSelectDoesNotGetOverwritten | code-review-only | P1 |
| R069 | Замена токена уничтожает цвет/формат rich text вне токена | testNativeRichTextViewRetainsFormattingOutsideToken — NSTextView harness, не все приложения | code-review-only | P1 |
| R070 | Реальный event tap/AX в стороннем редакторе ведёт себя иначе, чем синтетическая модель | Будущий изолированный physical smoke: EN/RU, смена focus, Secure Input, отзыв AX; реальные редакторы в этом аудите не открывались | unverified | P1 |

### Скриншоты — 14 сценариев

| ID | Конкретный риск / проверяемый сценарий | Evidence / test name | Статус | Severity |
|---|---|---|---|---|
| R071 | Return до готовности frozen image создаёт пустой снимок | testKeyboardAndAccessibilityCannotCaptureBeforeImageArrives | code-review-only | P2 |
| R072 | Первый Return неожиданно снимает экран вместо подготовки видимой области; стрелки выходят за края | testKeyboardCaptureCreatesMovesResizesAndConfirmsRegion | code-review-only | P2 |
| R073 | Crop на Retina с отрицательным origin выбирает соседние пиксели | testCropCoordinatesOnRetinaAndNegativeOrigin | code-review-only | P2 |
| R074 | Overlay frame и ScreenCaptureKit contentRect разного размера дают ошибочную область | testCropMapsOverlaySelectionIntoDifferentCaptureGeometry | code-review-only | P2 |
| R075 | Stale preferred display ID подменяется неоднозначным дисплеем | testDisplayRecoveryUsesTheActuallyAvailableDisplayID | code-review-only | P2 |
| R076 | Большой Retina display превышает pixel budget ещё до выбора небольшой области | testCapturePixelSizeDownscalesLargeRetinaDisplayWithoutExceedingBudget | unverified | P2 |
| R077 | Скрытые redaction пиксели влияют на PNG/JPEG или остаются в метаданных | testRedactedSecretsProduceIdenticalPNGAndJPEG | code-review-only | P1 |
| R078 | Copy во время кодирования перезаписывает более новое содержимое clipboard | testCopyRejectsInterveningClipboardWriteWithoutChangingIt — named pasteboard fixture, не запускался | code-review-only | P1 |
| R079 | Copy не включает ещё редактируемую текстовую аннотацию | testCopyActionCommitsActiveTextBeforeTakingExportSnapshot | unverified | P2 |
| R080 | Field editor обрабатывает Enter дважды или сохраняет draft после Escape | testNativeFieldEditorEnterCommitsOnceAndEscapeDiscardsDraft | unverified | P2 |
| R081 | Ошибка сохранения повреждает существующую цель или оставляет partial output | testSaveFailurePreservesDirectoryAndDoesNotLeavePartialOutput | unverified | P1 |
| R082 | Переключение PNG/JPEG в Save panel оставляет несовместимое имя/allowed type | testRememberedFormatAndPopupKeepFilenameAndAllowedTypeConsistent; физический Save-dialog не проверен | unverified | P2 |
| R083 | Escape во время незавершённого capture не позволяет новый запуск; поздняя обычная ошибка показывает alert | S4; P-S4 | code-review-only | P2 |
| R084 | Смена Spaces/мониторов во время реального capture делает экран/геометрию непригодными | Будущий изолированный physical smoke; ScreenshotCoordinator screen observer и generation guards не доказывают реальный multi-display результат | unverified | P2 |

### Хранение — 10 сценариев

| ID | Конкретный риск / проверяемый сценарий | Evidence / test name | Статус | Severity |
|---|---|---|---|---|
| R085 | Backup временно доступен посторонним до настройки permissions или затирает collision | testTemporaryBackupIsPrivateBeforeSQLiteAndDoesNotReplaceCollisions | unverified | P1 |
| R086 | Ошибка публикации backup портит старый файл либо меняет режим пользовательской папки | testBackupPreservesExistingFolderModeAndFailedPublicationPreservesOldFile | unverified | P1 |
| R087 | Restore переносит чужие triggers/views/несовместимую схему в рабочую БД | testRestoreRejectsIncompatibleSchemaAndNeverCopiesExecutableObjects | unverified | P1 |
| R088 | Unknown migrations/generated columns/extreme sortIndex проходят в restore | testRestoreRejectsUnknownMigrationsGeneratedColumnsAndExtremeOrdering | unverified | P1 |
| R089 | Restore открывает symbolic link до проверки входного файла | testRestoreRejectsSymbolicLinkBeforeOpeningSQLite | unverified | P1 |
| R090 | Чрезмерный backup читается целиком до проверки размера | testRestoreRejectsOversizedFileBeforeOpeningSQLite | unverified | P2 |
| R091 | Невалидный restore меняет текущие данные до завершения validation | testInvalidRestoreDoesNotChangeLiveData | unverified | P1 |
| R092 | Частичная erasure следует symlink либо оставляет активный undo с удалённым payload | testPartialErasureDoesNotFollowSymlinksAndStillInvalidatesViewsAndUndo | unverified | P1 |
| R093 | Неудачное удаление рабочей БД одновременно уничтожает restore snapshot | testFailedDatabaseErasurePreservesRestoreSnapshot | unverified | P1 |
| R094 | Полная очистка удаляет пользовательский export вместе с управляемыми snapshots | testDeleteAllUserDataRemovesManagedRestoreSnapshotsButPreservesUserExport | unverified | P1 |

### Производительность — 6 сценариев

| ID | Конкретный риск / проверяемый сценарий | Evidence / test name | Статус | Severity |
|---|---|---|---|---|
| R095 | При максимальной истории menu summaries материализуют image/RTF BLOB и тормозят открытие | testMenuReadsStayFastAtMaximumHistoryAfterLargeMigration — benchmark не запускался | unverified | P2 |
| R096 | Непустой поиск с limit=1 аллоцирует весь большой текстовый payload | S6; P-S6; testSyntheticHistorySearchLatencyAtRequestedSizes измеряет короткие строки и не запускался | code-review-only | P2 |
| R097 | Snippet menu limit применяется после чтения всей библиотеки и всех папок | testMenuSnippetSnapshotIsBoundedAndLoadsOnlyVisibleFolders | unverified | P2 |
| R098 | Успешный append всё равно строит лишние Data/title/hash нового отдельного элемента | testAppendBranchesPrecedeStandalonePayloadConstruction; Sources/NeClip/ClipboardMonitor.swift:417 | code-review-only | P3 |
| R099 | Заведомо oversized text проходит дорогую Unicode-нормализацию до size gate | testOversizeRejectionPrecedesUnicodeNormalization; ClipboardCapturePolicy.textRejectionReason | code-review-only | P2 |
| R100 | Большой литерал и текст с десятками тысяч неизвестных скобок вызывают чрезмерный рост работы renderer | testLargeLiteralTemplateAndBraceHeavyTextRemainUnchanged — проверяет результат, не latency; количественная performance-проверка отсутствует | code-review-only | P2 |

