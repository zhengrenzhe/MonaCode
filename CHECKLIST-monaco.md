# Monaco Editor 0.56.0 API/功能级 Checklist

> 唯一对标真源：`reference/monaco-editor-0.56.0.d.ts`（10240 行）。每项均来自该文件，未编造。
> 编号格式：`PREFIX-NNN`，扁平稳定，便于交叉引用。

---

## 目录与条目计数摘要

| 命名空间 | ID 前缀 | 条目数 |
|---|---|---|
| types（顶层类型） | TYPES | 17 |
| platform（平台基础设施） | PLAT | 12 |
| editor（编辑器） | EDITOR | 208 |
| languages（语言服务） | LANG | 193 |
| workers（Worker） | WORK | 8 |
| basic-languages（基础语言服务） | BLANG | 57 |
| lsp（LSP 客户端） | LSP | 6 |
| **合计** | | **501** |

---

## 1. types — 顶层类型（monaco 顶层导出）

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| TYPES-001 | UriComponents | interface | URI 的可序列化组件（scheme/authority/path/query/fragment） |
| TYPES-002 | Uri | class | 统一资源标识符，提供 parse/file/from/joinPath/revive/fsPath/with 等静态与实例方法 |
| TYPES-003 | KeyCode | enum | 虚拟键码枚举（Backspace=1 … MAX_VALUE=132），跨浏览器/OS 通用 |
| TYPES-004 | KeyMod | class | 键修饰符常量（CtrlCmd/Shift/Alt/WinCtrl）及 chord 组合方法 |
| TYPES-005 | IMarkdownString | interface | Markdown 字符串，含 isTrusted/supportThemeIcons/supportHtml/baseUri/uris |
| TYPES-006 | MarkdownStringTrustedOptions | interface | 受信 Markdown 的允许命令列表（enabledCommands） |
| TYPES-007 | IKeyboardEvent | interface | 标准化键盘事件，含 ctrlKey/shiftKey/altKey/metaKey/keyCode/code 及 preventDefault/stopPropagation |
| TYPES-008 | IMouseEvent | interface | 标准化鼠标事件，含 leftButton/middleButton/rightButton/posx/posy/ctrlKey 等 |
| TYPES-009 | IScrollEvent | interface | 滚动事件，含 scrollTop/scrollLeft/scrollWidth/scrollHeight 及各字段变更标记 |
| TYPES-010 | IPosition | interface | 编辑器位置（lineNumber 从 1 起，column 从 1 起），可序列化 |
| TYPES-011 | Position | class | 位置类，提供 with/delta/equals/isBefore/isBeforeOrEqual/compare/clone/lift/isIPosition/toJSON |
| TYPES-012 | IRange | interface | 编辑器范围（startLineNumber/startColumn/endLineNumber/endColumn），可序列化 |
| TYPES-013 | Range | class | 范围类，提供 isEmpty/containsPosition/containsRange/plusRange/intersectRanges/equalsRange/delta/collapseToStart/collapseToEnd/isSingleLine/lift/isIRange/areIntersectingOrTouching/compareRangesUsingStarts/compareRangesUsingEnds/spansMultipleLines/fromPositions 等静态与实例方法 |
| TYPES-014 | ISelection | interface | 选区（selectionStartLineNumber/Column + positionLineNumber/Column），可序列化 |
| TYPES-015 | Selection | class | 选区类，继承 Range，提供方向感知（getDirection/setEndPosition/setStartPosition）、selectionsEqual/fromPositions/fromRange/liftSelection/isISelection/createWithDirection 等静态与实例方法 |
| TYPES-016 | SelectionDirection | enum | 选区方向：LTR=0（从上到下）、RTL=1（从下到上） |
| TYPES-017 | Token | class | 词法 Token（offset/type/language），含 toString |

---

## 2. platform — 平台基础设施（全局/跨命名空间）

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| PLAT-001 | MonacoEnvironment | 全局变量 | 全局 Monaco 环境配置（globalAPI/baseUrl/getWorker/getWorkerUrl/createTrustedTypesPolicy），声明于 `declare global` |
| PLAT-002 | Environment | interface | 环境配置接口：globalAPI、baseUrl、getWorker（worker 工厂）、getWorkerUrl（worker 脚本 URL）、createTrustedTypesPolicy |
| PLAT-003 | ITrustedTypePolicyOptions | interface | Trusted Types 策略选项：createHTML/createScript/createScriptURL |
| PLAT-004 | ITrustedTypePolicy | interface | Trusted Types 策略：name + createHTML/createScript/createScriptURL |
| PLAT-005 | IDisposable | interface | 可释放资源接口，提供 dispose(): void |
| PLAT-006 | IEvent\<T\> | interface | 事件监听器函数类型 `(listener, thisArg?) => IDisposable` |
| PLAT-007 | Emitter\<T\> | class | 事件发射器，提供 readonly event、fire(event)、dispose() |
| PLAT-008 | CancellationTokenSource | class | 取消令牌源，提供 token 属性、cancel()、dispose(cancel?) |
| PLAT-009 | CancellationToken | interface | 取消令牌：isCancellationRequested + onCancellationRequested 事件 |
| PLAT-010 | MarkerSeverity | enum | 标记严重级别：Hint=1, Info=2, Warning=4, Error=8 |
| PLAT-011 | MarkerTag | enum | 标记标签：Unnecessary=1, Deprecated=2 |
| PLAT-012 | Thenable\<T\> | type | PromiseLike\<T\> 的别名 |

---

## 3. editor — 编辑器命名空间（monaco.editor）

### 3.1 编辑器创建与生命周期

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| EDITOR-001 | create | 方法 | 在 DOM 元素下创建独立代码编辑器，返回 IStandaloneCodeEditor |
| EDITOR-002 | createDiffEditor | 方法 | 在 DOM 元素下创建独立差异编辑器，返回 IStandaloneDiffEditor |
| EDITOR-003 | createMultiFileDiffEditor | 方法 | 创建多文件差异编辑器 |
| EDITOR-004 | onDidCreateEditor | 方法 | 编辑器创建时触发的事件监听器注册函数 |
| EDITOR-005 | onDidCreateDiffEditor | 方法 | 差异编辑器创建时触发的事件监听器注册函数 |
| EDITOR-006 | getEditors | 方法 | 获取所有已创建的代码编辑器列表 |
| EDITOR-007 | getDiffEditors | 方法 | 获取所有已创建的差异编辑器列表 |
| EDITOR-008 | IStandaloneCodeEditor | interface | 独立代码编辑器接口，扩展 ICodeEditor，增加 updateOptions/addCommand/createContextKey/addAction |
| EDITOR-009 | IStandaloneDiffEditor | interface | 独立差异编辑器接口，扩展 IDiffEditor，增加 addCommand/createContextKey/addAction/getOriginalEditor/getModifiedEditor |
| EDITOR-010 | IStandaloneEditorConstructionOptions | interface | 独立编辑器创建选项（model/value/language/theme/autoDetectHighContrast/accessibilityHelpUrl/ariaContainerElement），扩展 IEditorConstructionOptions + IGlobalEditorOptions |
| EDITOR-011 | IStandaloneDiffEditorConstructionOptions | interface | 独立差异编辑器创建选项（theme/autoDetectHighContrast），扩展 IDiffEditorConstructionOptions |
| EDITOR-012 | EditorType | 常量 | 编辑器类型常量：ICodeEditor、IDiffEditor |
| EDITOR-013 | EditorZoom | 常量 | 编辑器缩放管理器（IEditorZoom），含 onDidChangeZoomLevel/getZoomLevel/setZoomLevel |
| EDITOR-014 | IEditorZoom | interface | 编辑器缩放接口 |

### 3.2 模型层

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| EDITOR-015 | createModel | 方法 | 创建新的编辑器模型（value/language/uri），返回 ITextModel |
| EDITOR-016 | setModelLanguage | 方法 | 更改模型的语言 |
| EDITOR-017 | getModel | 方法 | 按 URI 获取已存在的模型 |
| EDITOR-018 | getModels | 方法 | 获取所有已创建的模型 |
| EDITOR-019 | onDidCreateModel | 方法 | 模型创建时触发的事件 |
| EDITOR-020 | onWillDisposeModel | 方法 | 模型即将销毁时触发的事件 |
| EDITOR-021 | onDidChangeModelLanguage | 方法 | 模型语言更改时触发的事件 |
| EDITOR-022 | ITextModel | interface | 文本模型接口：uri/id、getValue/setValue/getLineContent/getLinesContent、findMatches/findNextMatch/findPreviousMatch、pushEditOperations/applyEdits/pushEOL、deltaDecorations/getDecorationsInRange/getAllDecorations、undo/redo/canUndo/canRedo、onDidChangeContent/onDidChangeDecorations/onDidChangeOptions/onDidChangeLanguage/onDidChangeLanguageConfiguration/onDidChangeAttached/onWillDispose、getOffsetAt/getPositionAt/getFullModelRange、detectIndentation/updateOptions/normalizeIndentation/pushStackElement/popStackElement、isAttachedToEditor/isDisposed/dispose |
| EDITOR-023 | TextModelResolvedOptions | class | 已解析的模型选项（tabSize/indentSize/insertSpaces/defaultEOL/trimAutoWhitespace/bracketPairColorizationOptions/originalIndentSize） |
| EDITOR-024 | BracketPairColorizationOptions | interface | 括号对着色选项（enabled/independentColorPoolPerBracketType） |
| EDITOR-025 | ITextModelUpdateOptions | interface | 模型更新选项（tabSize/indentSize/insertSpaces/trimAutoWhitespace/bracketColorizationOptions） |
| EDITOR-026 | ITextSnapshot | interface | 文本快照迭代器（read() 返回 ~64KB 块或 null） |
| EDITOR-027 | FindMatch | class | 查找匹配结果（range/matches） |
| EDITOR-028 | IWordAtPosition | interface | 位置处的单词（word/startColumn/endColumn） |
| EDITOR-029 | IReadOnlyModel | 类型别名 | ITextModel 的兼容别名 |
| EDITOR-030 | IModel | 类型别名 | ITextModel 的兼容别名 |
| EDITOR-031 | IEditorModel | 类型 | 编辑器模型联合类型：ITextModel \| IDiffEditorModel \| IDiffEditorViewModel |

### 3.3 编辑器选项（IEditorOptions 及子选项）

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| EDITOR-032 | IEditorOptions | interface | 编辑器全部配置选项（~150+ 字段，含字体/光标/滚动/换行/minimap/scrollbar/folding/hover/suggest/inlayHints/padding/guides/unicodeHighlight/bracketPairColorization/dropIntoEditor/pasteAs/editContext 等） |
| EDITOR-033 | IGlobalEditorOptions | interface | 全局编辑器选项（tabSize/insertSpaces/detectIndentation/trimAutoWhitespace/largeFileOptimizations/wordBasedSuggestions/semanticHighlighting/stablePeek/maxTokenizationLineLength/theme/autoDetectHighContrast） |
| EDITOR-034 | IEditorConstructionOptions | interface | 编辑器构造选项，扩展 IEditorOptions 增加 dimension/overflowWidgetsDomNode |
| EDITOR-035 | IDiffEditorOptions | interface | 差异编辑器选项，扩展 IEditorOptions + IDiffEditorBaseOptions |
| EDITOR-036 | IDiffEditorBaseOptions | interface | 差异编辑器基础选项（enableSplitViewResizing/splitViewDefaultRatio/renderSideBySide/renderSideBySideInlineBreakpoint/useInlineViewWhenSpaceIsLimited/compactMode/maxComputationTime/maxFileSize/ignoreTrimWhitespace/renderIndicators/renderMarginRevertIcon/renderGutterMenu/originalEditable/diffCodeLens/renderOverviewRuler/diffWordWrap/diffAlgorithm/accessibilityVerbose/experimental/showMoves/showEmptyDecorations/useTrueInlineView/isInEmbeddedEditor/onlyShowAccessibleDiffViewer/hideUnchangedRegions） |
| EDITOR-037 | IDiffEditorConstructionOptions | interface | 差异编辑器构造选项，扩展 IDiffEditorOptions + IEditorConstructionOptions 增加 overflowWidgetsDomNode/originalAriaLabel/modifiedAriaLabel |
| EDITOR-038 | EditorOption | enum | 编辑器选项 ID 枚举（174 个值：acceptSuggestionOnCommitCharacter=0 … doubleClickSelectsBlock=173），用于 ConfigurationChangedEvent.hasChanged 和 getOption |
| EDITOR-039 | EditorOptions | 常量 | 编辑器选项定义注册表，为每个 EditorOption 提供 IEditorOption 实例 |
| EDITOR-040 | IEditorOption\<K,V\> | interface | 编辑器选项定义（id/name/defaultValue/applyUpdate） |
| EDITOR-041 | ApplyUpdateResult\<T\> | class | 选项更新结果（newValue/didChange） |
| EDITOR-042 | ConfigurationChangedEvent | class | 配置变更事件，提供 hasChanged(id) 查询 |
| EDITOR-043 | IComputedEditorOptions | interface | 已计算的编辑器选项集合，提供 get\<T\>(id) |
| EDITOR-044 | IEditorScrollbarOptions | interface | 滚动条选项（arrowSize/vertical/horizontal/useShadows/verticalHasArrows/horizontalHasArrows/handleMouseWheel/alwaysConsumeMouseWheel/horizontalScrollbarSize/verticalScrollbarSize/verticalSliderSize/horizontalSliderSize/scrollByPage/ignoreHorizontalScrollbarInContentHeight） |
| EDITOR-045 | InternalEditorScrollbarOptions | interface | 内部已解析的滚动条选项 |
| EDITOR-046 | IEditorMinimapOptions | interface | Minimap 选项（enabled/autohide/side/size/showSlider/renderCharacters/maxColumn/scale/showRegionSectionHeaders/showMarkSectionHeaders/markSectionHeaderRegex/sectionHeaderFontSize/sectionHeaderLetterSpacing） |
| EDITOR-047 | IEditorHoverOptions | interface | 悬停选项（enabled/delay/sticky/hidingDelay/above/showLongLineWarning） |
| EDITOR-048 | IEditorFindOptions | interface | 查找组件选项（cursorMoveOnType/findOnType/seedSearchStringFromSelection/autoFindInSelection/addExtraSpaceOnTop/loop/closeOnResult） |
| EDITOR-049 | IEditorStickyScrollOptions | interface | 粘性滚动选项（enabled/maxLineCount/defaultModel/scrollWithEditor） |
| EDITOR-050 | IEditorInlayHintsOptions | interface | Inlay Hints 选项（enabled/fontSize/fontFamily/padding/maximumLength） |
| EDITOR-051 | IEditorPaddingOptions | interface | 编辑器内边距（top/bottom） |
| EDITOR-052 | IEditorParameterHintOptions | interface | 参数提示选项（enabled/cycle） |
| EDITOR-053 | IEditorLightbulbOptions | interface | 灯泡选项（enabled: ShowLightbulbIconMode） |
| EDITOR-054 | IEditorCommentsOptions | interface | 注释选项（insertSpace/ignoreEmptyLines） |
| EDITOR-055 | ISuggestOptions | interface | 建议组件选项（insertMode/filterGraceful/snippetsPreventQuickSuggestions/localityBonus/shareSuggestSelections/selectionMode/showIcons/showStatusBar/preview/previewMode/showInlineDetails/showMethods…showSnippets 等 ~40 个可见性开关） |
| EDITOR-056 | IInlineSuggestOptions | interface | 内联建议选项（enabled/mode/showToolbar/syntaxHighlightingEnabled/suppressSuggestions/minShowDelay/suppressInSnippetMode/keepOnBlur/fontFamily） |
| EDITOR-057 | ISmartSelectOptions | interface | 智能选择选项（selectLeadingAndTrailingWhitespace/selectSubwords） |
| EDITOR-058 | IGotoLocationOptions | interface | 跳转位置选项（multiple/multipleDefinitions/multipleTypeDefinitions/multipleDeclarations/multipleImplementations/multipleReferences/multipleTests/alternative*Command） |
| EDITOR-059 | IQuickSuggestionsOptions | interface | 快速建议选项（other/comments/strings） |
| EDITOR-060 | QuickSuggestionsValue | 类型 | 快速建议值：'on'\|'inline'\|'off'\|'offWhenInlineCompletions' |
| EDITOR-061 | IGuidesOptions | interface | 参考线选项（bracketPairs/bracketPairsHorizontal/highlightActiveBracketPair/indentation/highlightActiveIndentation） |
| EDITOR-062 | IBracketPairColorizationOptions | interface | 括号对着色选项（enabled/independentColorPoolPerBracketType） |
| EDITOR-063 | IUnicodeHighlightOptions | interface | Unicode 高亮选项（nonBasicASCII/invisibleCharacters/ambiguousCharacters/includeComments/includeStrings/allowedCharacters/allowedLocales） |
| EDITOR-064 | IDropIntoEditorOptions | interface | 拖入编辑器选项（enabled/showDropSelector） |
| EDITOR-065 | IPasteAsOptions | interface | 粘贴为选项（enabled/showPasteSelector） |
| EDITOR-066 | LineNumbersType | 类型 | 行号类型：'on'\|'off'\|'relative'\|'interval'\|((lineNumber)=>string) |
| EDITOR-067 | RenderLineNumbersType | enum | 行号渲染类型：Off=0/On=1/Relative=2/Interval=3/Custom=4 |
| EDITOR-068 | InternalEditorRenderLineNumbersOptions | interface | 内部行号渲染选项（renderType/renderFn） |
| EDITOR-069 | IRulerOption | interface | 标尺线选项（column/color） |
| EDITOR-070 | EditorAutoClosingStrategy | 类型 | 自动关闭策略：'always'\|'languageDefined'\|'beforeWhitespace'\|'never' |
| EDITOR-071 | EditorAutoSurroundStrategy | 类型 | 自动包围策略：'languageDefined'\|'quotes'\|'brackets'\|'never' |
| EDITOR-072 | EditorAutoClosingEditStrategy | 类型 | 自动关闭编辑策略：'always'\|'auto'\|'never' |
| EDITOR-073 | EditorAutoIndentStrategy | enum | 自动缩进策略：None=0/Keep=1/Brackets=2/Advanced=3/Full=4 |
| EDITOR-074 | TextEditorCursorBlinkingStyle | enum | 光标闪烁样式：Hidden=0/Blink=1/Smooth=2/Phase=3/Expand=4/Solid=5 |
| EDITOR-075 | TextEditorCursorStyle | enum | 光标样式：Line=1/Block=2/Underline=3/LineThin=4/BlockOutline=5/UnderlineThin=6 |
| EDITOR-076 | WrappingIndent | enum | 换行缩进：None=0/Same=1/Indent=2/DeepIndent=3 |
| EDITOR-077 | EditorWrappingInfo | interface | 换行信息（isDominatedByLongLines/isWordWrapMinified/isViewportWrapping/wrappingColumn） |
| EDITOR-078 | RenderMinimap | enum | Minimap 渲染模式：None=0/Text=1/Blocks=2 |
| EDITOR-079 | ScrollbarVisibility | enum | 滚动条可见性：Auto=1/Hidden=2/Visible=3 |
| EDITOR-080 | ShowLightbulbIconMode | enum | 灯泡图标模式：Off/OnCode/On |
| EDITOR-081 | AccessibilitySupport | enum | 无障碍支持：Unknown=0/Disabled=1/Enabled=2 |
| EDITOR-082 | ScrollType | enum | 滚动类型：Smooth=0/Immediate=1 |
| EDITOR-083 | MouseMiddleClickAction | 类型 | 鼠标中键动作：'default'\|'openLink'\|'ctrlLeftClick' |
| EDITOR-084 | GoToLocationValues | 类型 | 跳转位置值：'peek'\|'gotoAndPeek'\|'goto' |
| EDITOR-085 | InUntrustedWorkspace | 类型 | 不受信工作区标记：'inUntrustedWorkspace' |
| EDITOR-086 | EditorLayoutInfo | interface | 编辑器内部布局信息（width/height/glyphMarginLeft/Width/lineNumbersLeft/Width/decorationsLeft/Width/contentLeft/Width/minimap/viewportColumn/isWordWrapMinified/isViewportWrapping/wrappingColumn/verticalScrollbarWidth/horizontalScrollbarHeight/overviewRuler/glyphMarginDecorationLaneCount） |
| EDITOR-087 | EditorMinimapLayoutInfo | interface | Minimap 布局信息（renderMinimap/minimapLeft/Width/HeightIsEditorHeight/minimapIsSampling/minimapScale/minimapLineHeight/minimapCanvasInnerWidth/Height/minimapCanvasOuterWidth/Height） |
| EDITOR-088 | OverviewRulerPosition | interface | 概览标尺位置（width/height/top/right） |
| EDITOR-089 | FontInfo | class | 字体信息（isMonospace/typicalHalfwidthCharacterWidth/spaceWidth/maxDigitWidth 等度量值），继承 BareFontInfo |
| EDITOR-090 | BareFontInfo | class | 基础字体信息（pixelRatio/fontFamily/fontWeight/fontSize/fontFeatureSettings/fontVariationSettings/lineHeight/letterSpacing） |

### 3.4 编辑器核心接口（IEditor / ICodeEditor / IDiffEditor）

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| EDITOR-091 | IEditor | interface | 编辑器基础接口：onDidDispose/dispose/getId/getEditorType/updateOptions/layout/focus/hasTextFocus/getSupportedActions/saveViewState/restoreViewState/getVisibleColumnFromPosition/getPosition/setPosition/revealLine*/revealPosition*/getSelection/getSelections/setSelection/setSelections/revealLines*/revealRange*/trigger/getModel/setModel/createDecorationsCollection |
| EDITOR-092 | ICodeEditor | interface | 富代码编辑器接口，扩展 IEditor：onDidChangeModelContent/Language/LanguageConfiguration/Options/Configuration/CursorPosition/CursorSelection/Decorations、onWill/DidChangeModel、onDidFocus/BlurEditorText/Widget、onDidCompositionStart/End、onDidAttemptReadOnlyEdit、onDidPaste、onMouseUp/Down/Move/Leave、onContextMenu、onKeyUp/Down、onDidLayoutChange/ContentSizeChange/ScrollChange/HiddenAreas、onBeginUpdate/onEndUpdate/onDidChangeViewZones、getContribution/getModel/setModel/getOptions/getOption/getRawOptions/getValue/setValue/getContentWidth/Height/getScrollWidth/Height/Left/Top/setScrollLeft/Top/Position/hasPendingScrollAnimation/getAction/executeCommand/pushUndoStop/popUndoStop/executeEdits/executeCommands/revealAllCursors/getLineDecorations/getDecorationsInRange/getFontSizeAtPosition/deltaDecorations/removeDecorations/getLayoutInfo/getVisibleRanges/getTopForLineNumber/getBottomForLineNumber/getTopForPosition/getLineHeightForPosition/writeScreenReaderContent/getContainerDomNode/getDomNode/addContentWidget/layoutContentWidget/removeContentWidget/addOverlayWidget/layoutOverlayWidget/removeOverlayWidget/addGlyphMarginWidget/layoutGlyphMarginWidget/removeGlyphMarginWidget/changeViewZones/getOffsetForColumn/getWidthOfLine/render/renderAsync/getTargetAtClientPoint/getScrolledVisiblePosition/applyFontInfo/setBanner/handleInitialized |
| EDITOR-093 | IDiffEditor | interface | 富差异编辑器接口，扩展 IEditor：getContainerDomNode、onDidUpdateDiff、onDidChangeModel、saveViewState/restoreViewState、getModel/createViewModel/setModel、getOriginalEditor/getModifiedEditor、getLineChanges、updateOptions、goToDiff、revealFirstDiff、accessibleDiffViewerNext/Prev、handleInitialized |
| EDITOR-094 | IEditorAction | interface | 编辑器动作（id/label/alias/metadata/isSupported/run） |
| EDITOR-095 | IEditorContribution | interface | 编辑器贡献（dispose/saveViewState?/restoreViewState?） |
| EDITOR-096 | IEditorDecorationsCollection | interface | 编辑器装饰集合（onDidChange/length/getRange/getRanges/has/set/append/clear） |

### 3.5 装饰（Decorations）

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| EDITOR-097 | IModelDecorationOptions | interface | 模型装饰选项（stickiness/className/shouldFillLineOnLineBreak/blockClassName/blockIsAfterEnd/blockDoesNotCollapse/blockPadding/glyphMarginHoverMessage/hoverMessage/lineNumberHoverMessage/isWholeLine/showIfCollapsed/zIndex/overviewRuler/minimap/glyphMargin/glyphMarginClassName/lineHeight/fontFamily/fontSize/fontWeight/fontStyle/linesDecorationsClassName/linesDecorationsTooltip/lineNumberClassName/firstLineDecorationClassName/marginClassName/inlineClassName/inlineClassNameAffectsLetterSpacing/beforeContentClassName/afterContentClassName/after/before/textDirection） |
| EDITOR-098 | IModelDeltaDecoration | interface | 新增模型装饰（range + options） |
| EDITOR-099 | IModelDecoration | interface | 模型中的装饰（id/ownerId/range/options） |
| EDITOR-100 | IDecorationOptions | interface | 装饰基础选项（color/darkColor） |
| EDITOR-101 | IModelDecorationOverviewRulerOptions | interface | 概览标尺装饰选项（position: OverviewRulerLane） |
| EDITOR-102 | IModelDecorationMinimapOptions | interface | Minimap 装饰选项（position/sectionHeaderStyle/sectionHeaderText） |
| EDITOR-103 | IModelDecorationGlyphMarginOptions | interface | 字形边距装饰选项（position: GlyphMarginLane/persistLane） |
| EDITOR-104 | InjectedTextOptions | interface | 注入文本选项（content/inlineClassName/inlineClassNameAffectsLetterSpacing/attachedData/cursorStops） |
| EDITOR-105 | InjectedTextCursorStops | enum | 注入文本光标停止位置：Both=0/Right=1/Left=2/None=3 |
| EDITOR-106 | TrackedRangeStickiness | enum | 装饰粘性：AlwaysGrowsWhenTypingAtEdges=0/NeverGrowsWhenTypingAtEdges=1/GrowsOnlyWhenTypingBefore=2/GrowsOnlyWhenTypingAfter=3 |
| EDITOR-107 | TextDirection | enum | 文本方向：LTR=0/RTL=1 |
| EDITOR-108 | OverviewRulerLane | enum | 概览标尺车道：Left=1/Center=2/Right=4/Full=7 |
| EDITOR-109 | GlyphMarginLane | enum | 字形边距车道：Left=1/Center=2/Right=3 |
| EDITOR-110 | MinimapPosition | enum | Minimap 位置：Inline=1/Gutter=2 |
| EDITOR-111 | MinimapSectionHeaderStyle | enum | Minimap 区段标题样式：Normal=1/Underlined=2 |
| EDITOR-112 | IGlyphMarginLanesModel | interface | 字形边距车道模型（requiredLanes/getLanesAtLine/reset/push） |

### 3.6 标记 / 诊断（Markers）

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| EDITOR-113 | IMarker | interface | 标记（owner/resource/severity/code/message/source/startLineNumber/startColumn/endLineNumber/endColumn/modelVersionId/relatedInformation/tags/origin） |
| EDITOR-114 | IMarkerData | interface | 标记数据（severity/message/startLineNumber/startColumn/endLineNumber/endColumn/code/source/modelVersionId/relatedInformation/tags/origin） |
| EDITOR-115 | IRelatedInformation | interface | 相关信息（resource/message/startLineNumber/startColumn/endLineNumber/endColumn） |
| EDITOR-116 | setModelMarkers | 方法 | 为模型设置标记 |
| EDITOR-117 | removeAllMarkers | 方法 | 移除某 owner 的所有标记 |
| EDITOR-118 | getModelMarkers | 方法 | 按 owner/resource 获取标记 |
| EDITOR-119 | onDidChangeMarkers | 方法 | 标记变更事件 |

### 3.7 编辑操作与命令

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| EDITOR-120 | ISingleEditOperation | interface | 单次编辑操作（range/text/forceMoveMarkers） |
| EDITOR-121 | IIdentifiedSingleEditOperation | interface | 带标识的编辑操作，扩展 ISingleEditOperation |
| EDITOR-122 | IValidEditOperation | interface | 已验证的编辑操作（range/text） |
| EDITOR-123 | ICursorStateComputer | interface | 编辑后光标状态计算回调 |
| EDITOR-124 | IEditOperationBuilder | interface | 编辑操作构建器（addEditOperation/addTrackedEditOperation/trackSelection） |
| EDITOR-125 | ICursorStateComputerData | interface | 光标状态计算辅助（getInverseEditOperations/getTrackedSelection） |
| EDITOR-126 | ICommand | interface | 文本/光标修改命令（getEditOperations/computeCursorState） |
| EDITOR-127 | EndOfLinePreference | enum | 行尾偏好：TextDefined=0/LF=1/CRLF=2 |
| EDITOR-128 | DefaultEndOfLine | enum | 默认行尾：LF=1/CRLF=2 |
| EDITOR-129 | EndOfLineSequence | enum | 行尾序列：LF=0/CRLF=1 |
| EDITOR-130 | PositionAffinity | enum | 位置偏好：Left=0/Right=1/None=2/LeftOfInjectedText=3/RightOfInjectedText=4 |

### 3.8 视图区/组件（View Zones / Widgets / Mouse）

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| EDITOR-131 | IViewZone | interface | 视图区（afterLineNumber/afterColumn/afterColumnAffinity/showInHiddenAreas/ordinal/suppressMouseDown/heightInLines/heightInPx/minWidthInPx/domNode/marginDomNode/onDomNodeTop/onComputedHeight） |
| EDITOR-132 | IViewZoneChangeAccessor | interface | 视图区变更访问器（addZone/removeZone/layoutZone） |
| EDITOR-133 | ContentWidgetPositionPreference | enum | 内容组件位置偏好：EXACT=0/ABOVE=1/BELOW=2 |
| EDITOR-134 | IContentWidgetPosition | interface | 内容组件位置（position/secondaryPosition/preference/positionAffinity） |
| EDITOR-135 | IContentWidget | interface | 内容组件（allowEditorOverflow/useDisplayNone/suppressMouseDown/getId/getDomNode/getPosition/beforeRender/afterRender） |
| EDITOR-136 | IContentWidgetRenderedCoordinate | interface | 内容组件渲染坐标（top/left） |
| EDITOR-137 | OverlayWidgetPositionPreference | enum | 叠加组件位置偏好：TOP_RIGHT_CORNER=0/BOTTOM_RIGHT_CORNER=1/TOP_CENTER=2 |
| EDITOR-138 | IOverlayWidgetPositionCoordinates | interface | 叠加组件坐标（top/left） |
| EDITOR-139 | IOverlayWidgetPosition | interface | 叠加组件位置（preference/stackOrdinal） |
| EDITOR-140 | IOverlayWidget | interface | 叠加组件（onDidLayout/allowEditorOverflow/getId/getDomNode/getPosition/getMinContentWidthInPx） |
| EDITOR-141 | IGlyphMarginWidget | interface | 字形边距组件（getId/getDomNode/getPosition） |
| EDITOR-142 | IGlyphMarginWidgetPosition | interface | 字形边距组件位置（lane/zIndex/range） |
| EDITOR-143 | MouseTargetType | enum | 鼠标目标类型（14 值：UNKNOWN=0…OUTSIDE_EDITOR=13） |
| EDITOR-144 | IBaseMouseTarget | interface | 基础鼠标目标（element/position/mouseColumn/range） |
| EDITOR-145 | IMouseTarget | 类型 | 所有鼠标目标类型的联合（IMouseTargetUnknown \| IMouseTargetTextarea \| IMouseTargetMargin \| IMouseTargetViewZone \| IMouseTargetContentText \| IMouseTargetContentEmpty \| IMouseTargetContentWidget \| IMouseTargetOverlayWidget \| IMouseTargetScrollbar \| IMouseTargetOverviewRuler \| IMouseTargetOutsideEditor） |
| EDITOR-146 | IEditorMouseEvent | interface | 编辑器鼠标事件（event/target） |
| EDITOR-147 | IPartialEditorMouseEvent | interface | 部分编辑器鼠标事件（event/target?） |
| EDITOR-148 | IPasteEvent | interface | 粘贴事件（range/languageId/clipboardEvent?） |

### 3.9 视图状态与事件

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| EDITOR-149 | ICursorState | interface | 可序列化光标状态（inSelectionMode/selectionStart/position） |
| EDITOR-150 | IViewState | interface | 可序列化视图状态（scrollTop?/scrollTopWithoutViewZones?/scrollLeft/firstPosition/firstPositionDeltaTop） |
| EDITOR-151 | ICodeEditorViewState | interface | 代码编辑器视图状态（cursorState/viewState/contributionsState） |
| EDITOR-152 | IDiffEditorViewState | interface | 差异编辑器视图状态（original/modified/modelState?） |
| EDITOR-153 | IEditorViewState | 类型 | 编辑器视图状态联合类型（ICodeEditorViewState \| IDiffEditorViewState） |
| EDITOR-154 | IModelChangedEvent | interface | 模型变更事件（oldModelUrl/newModelUrl） |
| EDITOR-155 | IContentSizeChangedEvent | interface | 内容尺寸变更事件（contentWidth/Height/contentWidthChanged/HeightChanged） |
| EDITOR-156 | INewScrollPosition | interface | 新滚动位置（scrollLeft?/scrollTop?） |
| EDITOR-157 | IModelContentChangedEvent | interface | 模型内容变更事件（changes/eol/versionId/isUndoing/isRedoing/isFlush/isEolChange/detailedReasonsChangeLengths） |
| EDITOR-158 | ISerializedModelContentChangedEvent | interface | 序列化的模型内容变更事件 |
| EDITOR-159 | IModelContentChange | interface | 内容变更（range/rangeOffset/rangeLength/text） |
| EDITOR-160 | IModelDecorationsChangedEvent | interface | 装饰变更事件（affectsMinimap/affectsOverviewRuler/affectsGlyphMargin/affectsLineNumber） |
| EDITOR-161 | IModelOptionsChangedEvent | interface | 模型选项变更事件（tabSize/indentSize/insertSpaces/trimAutoWhitespace） |
| EDITOR-162 | IModelLanguageChangedEvent | interface | 模型语言变更事件（oldLanguage/newLanguage/source） |
| EDITOR-163 | IModelLanguageConfigurationChangedEvent | interface | 模型语言配置变更事件 |
| EDITOR-164 | CursorChangeReason | enum | 光标变更原因：NotSet=0/ContentFlush=1/RecoverFromMarkers=2/Explicit=3/Paste=4/Undo=5/Redo=6 |
| EDITOR-165 | ICursorPositionChangedEvent | interface | 光标位置变更事件（position/secondaryPositions/reason/source） |
| EDITOR-166 | ICursorSelectionChangedEvent | interface | 光标选区变更事件（selection/secondarySelections/modelVersionId/oldSelections/oldModelVersionId/source/reason） |

### 3.10 差异编辑器模型

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| EDITOR-167 | IDiffEditorModel | interface | 差异编辑器模型（original: ITextModel + modified: ITextModel） |
| EDITOR-168 | IDiffEditorViewModel | interface | 差异编辑器视图模型（model/waitForDiff），扩展 IDisposable |
| EDITOR-169 | IChange | interface | 差异变更（originalStartLineNumber/EndLineNumber/modifiedStartLineNumber/EndLineNumber） |
| EDITOR-170 | ICharChange | interface | 字符级差异变更，扩展 IChange（originalStartColumn/EndColumn/modifiedStartColumn/EndColumn） |
| EDITOR-171 | ILineChange | interface | 行级差异变更，扩展 IChange（charChanges?） |
| EDITOR-172 | IDimension | interface | 尺寸（width/height） |

### 3.11 主题 / 着色 / 命令 / 链接

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| EDITOR-173 | BuiltinTheme | 类型 | 内置主题：'vs'\|'vs-dark'\|'hc-black'\|'hc-light' |
| EDITOR-174 | IStandaloneThemeData | interface | 独立主题数据（base/inherit/rules/encodedTokensColors/colors） |
| EDITOR-175 | IColors | 类型 | 颜色映射 `{ [colorId: string]: string }` |
| EDITOR-176 | ITokenThemeRule | interface | Token 主题规则（token/foreground?/background?/fontStyle?） |
| EDITOR-177 | ThemeColor | interface | 主题颜色引用（id） |
| EDITOR-178 | ThemeIcon | interface | 主题图标引用（id/color?） |
| EDITOR-179 | defineTheme | 方法 | 定义或更新主题 |
| EDITOR-180 | setTheme | 方法 | 切换主题 |
| EDITOR-181 | remeasureFonts | 方法 | 清除缓存字体度量并重新测量 |
| EDITOR-182 | colorizeElement | 方法 | 按 data-lang 属性着色 DOM 元素 |
| EDITOR-183 | colorize | 方法 | 按语言 ID 着色文本，返回 HTML |
| EDITOR-184 | colorizeModelLine | 方法 | 着色模型中某行 |
| EDITOR-185 | tokenize | 方法 | 按语言 ID 分词文本，返回 Token[][] |
| EDITOR-186 | IColorizerOptions | interface | 着色器选项（tabSize?） |
| EDITOR-187 | IColorizerElementOptions | interface | 着色器元素选项（theme?/mimeType?），扩展 IColorizerOptions |
| EDITOR-188 | registerCommand | 方法 | 注册命令（id + handler） |
| EDITOR-189 | addCommand | 方法 | 添加命令（ICommandDescriptor） |
| EDITOR-190 | addEditorAction | 方法 | 向所有编辑器添加动作（IActionDescriptor） |
| EDITOR-191 | addKeybindingRule | 方法 | 添加单条快捷键规则 |
| EDITOR-192 | addKeybindingRules | 方法 | 添加多条快捷键规则 |
| EDITOR-193 | ICommandDescriptor | interface | 命令描述（id/run） |
| EDITOR-194 | IKeybindingRule | interface | 快捷键规则（keybinding/command?/commandArgs?/when?） |
| EDITOR-195 | IActionDescriptor | interface | 动作描述（id/label/precondition?/keybindings?/keybindingContext?/contextMenuGroupId?/contextMenuOrder?/run） |
| EDITOR-196 | ICommandHandler | interface | 命令处理函数类型 |
| EDITOR-197 | ILocalizedString | interface | 本地化字符串（original/value） |
| EDITOR-198 | ICommandMetadata | interface | 命令元数据（description） |
| EDITOR-199 | IContextKey\<T\> | interface | 上下文键（set/reset/get） |
| EDITOR-200 | ContextKeyValue | 类型 | 上下文键值类型（null\|undefined\|boolean\|number\|string\|Array\|Record） |
| EDITOR-201 | IEditorOverrideServices | interface | 编辑器覆盖服务包（`[index: string]: unknown`） |
| EDITOR-202 | ILinkOpener | interface | 链接打开器（open(resource): boolean\|Promise\<boolean\>） |
| EDITOR-203 | registerLinkOpener | 方法 | 注册链接打开器 |
| EDITOR-204 | ICodeEditorOpener | interface | 代码编辑器打开器（openCodeEditor） |
| EDITOR-205 | registerEditorOpener | 方法 | 注册编辑器打开器 |
| EDITOR-206 | createWebWorker | 方法 | 创建带模型同步能力的 Web Worker |
| EDITOR-207 | MonacoWebWorker\<T\> | interface | Web Worker 代理（dispose/getProxy/withSyncedResources） |
| EDITOR-208 | IInternalWebWorkerOptions | interface | Web Worker 选项（worker/host?/keepIdleModels?） |

---

## 4. languages — 语言服务命名空间（monaco.languages）

### 4.1 语言注册与配置

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| LANG-001 | register | 方法 | 注册新语言信息（ILanguageExtensionPoint） |
| LANG-002 | getLanguages | 方法 | 获取所有已注册语言信息 |
| LANG-003 | getEncodedLanguageId | 方法 | 获取语言 ID 的编码数值 |
| LANG-004 | onLanguage | 方法 | 语言首次关联到文本模型时触发的事件 |
| LANG-005 | onLanguageEncountered | 方法 | 语言首次关联到模型或在分词中遇到时触发的事件 |
| LANG-006 | setLanguageConfiguration | 方法 | 设置语言的编辑配置（LanguageConfiguration） |
| LANG-007 | ILanguageExtensionPoint | interface | 语言扩展点定义（id/extensions?/filenames?/filenamePatterns?/firstLine?/aliases?/mimetypes?/configuration?） |
| LANG-008 | LanguageConfiguration | interface | 语言配置（comments/brackets/wordPattern/indentationRules/onEnterRules/autoClosingPairs/surroundingPairs/colorizedBracketPairs/autoCloseBefore/folding/__electricCharacterSupport?） |
| LANG-009 | CommentRule | interface | 注释规则（lineComment?/blockComment?） |
| LANG-010 | LineCommentConfig | interface | 行注释配置（comment/noIndent?） |
| LANG-011 | CharacterPair | 类型 | 字符对 `[string, string]` |
| LANG-012 | IAutoClosingPair | interface | 自动关闭对（open/close） |
| LANG-013 | IAutoClosingPairConditional | interface | 条件自动关闭对，扩展 IAutoClosingPair（notIn?） |
| LANG-014 | IndentationRule | interface | 缩进规则（decreaseIndentPattern/increaseIndentPattern/indentNextLinePattern?/unIndentedLinePattern?） |
| LANG-015 | OnEnterRule | interface | 回车规则（beforeText/afterText?/previousLineText?/action） |
| LANG-016 | EnterAction | interface | 回车动作（indentAction/appendText?/removeText?） |
| LANG-017 | IndentAction | enum | 缩进动作：None=0/Indent=1/IndentOutdent=2/Outdent=3 |
| LANG-018 | IDocComment | interface | 文档注释（open/close?） |
| LANG-019 | FoldingRules | interface | 折叠规则（offSide?/markers?） |
| LANG-020 | FoldingMarkers | interface | 折叠标记（start/end: RegExp） |
| LANG-021 | LanguageSelector | 类型 | 语言选择器：string\|LanguageFilter\|ReadonlyArray |
| LANG-022 | LanguageFilter | interface | 语言过滤器（language?/scheme?/pattern?/notebookType?/hasAccessToAllModels?/exclusive?/isBuiltin?） |
| LANG-023 | IRelativePattern | interface | 相对模式（base/pattern） |

### 4.2 分词 / Monarch

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| LANG-024 | IState | interface | 分词器状态接口（clone/equals） |
| LANG-025 | IToken | interface | Token（startIndex/scopes） |
| LANG-026 | ILineTokens | interface | 行分词结果（tokens: IToken[]/endState: IState） |
| LANG-027 | IEncodedLineTokens | interface | 编码行分词结果（tokens: Uint32Array/endState: IState），含二进制 metadata 格式说明 |
| LANG-028 | TokensProviderFactory | interface | Token 提供者工厂（create） |
| LANG-029 | TokensProvider | interface | 手动 Token 提供者（getInitialState/tokenize） |
| LANG-030 | EncodedTokensProvider | interface | 编码 Token 提供者（getInitialState/tokenizeEncoded/tokenize?） |
| LANG-031 | registerTokensProviderFactory | 方法 | 注册 Token 提供者工厂 |
| LANG-032 | setTokensProvider | 方法 | 设置 Token 提供者（手动实现） |
| LANG-033 | setMonarchTokensProvider | 方法 | 设置 Monarch Token 提供者 |
| LANG-034 | setColorMap | 方法 | 更改 Token 颜色映射 |
| LANG-035 | IMonarchLanguage | interface | Monarch 语言定义（tokenizer/ignoreCase?/unicode?/defaultToken?/brackets?/start?/tokenPostfix?/includeLF?） |
| LANG-036 | IMonarchLanguageRule | 类型 | Monarch 规则（IShortMonarchLanguageRule1 \| IShortMonarchLanguageRule2 \| IExpandedMonarchLanguageRule） |
| LANG-037 | IExpandedMonarchLanguageRule | interface | 展开的 Monarch 规则（regex?/action?/include?） |
| LANG-038 | IMonarchLanguageAction | 类型 | Monarch 动作（IShortMonarchLanguageAction \| IExpandedMonarchLanguageAction \| Array） |
| LANG-039 | IExpandedMonarchLanguageAction | interface | 展开的 Monarch 动作（group?/cases?/token?/next?/switchTo?/goBack?/bracket?/nextEmbedded?/log?） |
| LANG-040 | IMonarchLanguageBracket | interface | Monarch 括号（open/close/token） |
| LANG-041 | SyntaxNode | interface | 语法节点（startIndex/endIndex/startPosition/endPosition） |
| LANG-042 | QueryCapture | interface | 查询捕获（name/text?/node/encodedLanguageId） |
| LANG-043 | ProviderResult\<T\> | 类型 | 提供者返回类型：T\|undefined\|null\|Thenable |

### 4.3 语言服务 Provider 注册函数

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| LANG-044 | registerReferenceProvider | 方法 | 注册引用提供者 |
| LANG-045 | registerRenameProvider | 方法 | 注册重命名提供者 |
| LANG-046 | registerNewSymbolNameProvider | 方法 | 注册新符号名提供者 |
| LANG-047 | registerSignatureHelpProvider | 方法 | 注册签名帮助提供者 |
| LANG-048 | registerHoverProvider | 方法 | 注册悬停提供者 |
| LANG-049 | registerDocumentSymbolProvider | 方法 | 注册文档符号提供者 |
| LANG-050 | registerDocumentHighlightProvider | 方法 | 注册文档高亮提供者 |
| LANG-051 | registerLinkedEditingRangeProvider | 方法 | 注册链接编辑范围提供者 |
| LANG-052 | registerDefinitionProvider | 方法 | 注册定义提供者 |
| LANG-053 | registerImplementationProvider | 方法 | 注册实现提供者 |
| LANG-054 | registerTypeDefinitionProvider | 方法 | 注册类型定义提供者 |
| LANG-055 | registerCodeLensProvider | 方法 | 注册 CodeLens 提供者 |
| LANG-056 | registerCodeActionProvider | 方法 | 注册代码操作提供者 |
| LANG-057 | registerDocumentFormattingEditProvider | 方法 | 注册文档格式化提供者 |
| LANG-058 | registerDocumentRangeFormattingEditProvider | 方法 | 注册范围格式化提供者 |
| LANG-059 | registerOnTypeFormattingEditProvider | 方法 | 注册输入时格式化提供者 |
| LANG-060 | registerLinkProvider | 方法 | 注册链接提供者 |
| LANG-061 | registerCompletionItemProvider | 方法 | 注册补全项提供者 |
| LANG-062 | registerColorProvider | 方法 | 注册文档颜色提供者 |
| LANG-063 | registerFoldingRangeProvider | 方法 | 注册折叠范围提供者 |
| LANG-064 | registerDeclarationProvider | 方法 | 注册声明提供者 |
| LANG-065 | registerSelectionRangeProvider | 方法 | 注册选区范围提供者 |
| LANG-066 | registerDocumentSemanticTokensProvider | 方法 | 注册文档语义 Token 提供者 |
| LANG-067 | registerDocumentRangeSemanticTokensProvider | 方法 | 注册文档范围语义 Token 提供者 |
| LANG-068 | registerInlineCompletionsProvider | 方法 | 注册内联补全提供者 |
| LANG-069 | registerInlayHintsProvider | 方法 | 注册 Inlay Hints 提供者 |

### 4.4 Completion / Suggest

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| LANG-070 | CompletionItem | interface | 补全项（label/kind/tags?/detail?/documentation?/sortText?/filterText?/preselect?/insertText/insertTextRules?/range/commitCharacters?/additionalTextEdits?/command?/action?） |
| LANG-071 | CompletionItemLabel | interface | 补全项标签（label/detail?/description?） |
| LANG-072 | CompletionItemKind | enum | 补全项类型（29 值：Method=0…Snippet=28） |
| LANG-073 | CompletionItemTag | enum | 补全项标签：Deprecated=1 |
| LANG-074 | CompletionItemInsertTextRule | enum | 插入规则：None=0/KeepWhitespace=1/InsertAsSnippet=4 |
| LANG-075 | CompletionItemRanges | interface | 补全项范围（insert/replace） |
| LANG-076 | CompletionList | interface | 补全列表（suggestions/incomplete?/dispose?） |
| LANG-077 | CompletionContext | interface | 补全上下文（triggerKind/triggerCharacter?） |
| LANG-078 | CompletionTriggerKind | enum | 触发类型：Invoke=0/TriggerCharacter=1/TriggerForIncompleteCompletions=2 |
| LANG-079 | CompletionItemProvider | interface | 补全项提供者（triggerCharacters?/provideCompletionItems/resolveCompletionItem?） |
| LANG-080 | PartialAcceptInfo | interface | 部分接受信息（kind/acceptedLength） |
| LANG-081 | PartialAcceptTriggerKind | enum | 部分接受触发：Word=0/Line=1/Suggest=2 |

### 4.5 Inline Completions

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| LANG-082 | InlineCompletion | interface | 内联补全项（insertText/range?/additionalTextEdits?/uri?/command?/completeBracketPairs?/isInlineEdit?/showRange?/warning?/hint?/supportsRename? 等） |
| LANG-083 | InlineCompletions\<T\> | interface | 内联补全列表（items/commands?/suppressSuggestions?/enableForwardStability?） |
| LANG-084 | InlineCompletionsProvider\<T\> | interface | 内联补全提供者（provideInlineCompletions/handleItemDidShow?/handlePartialAccept?/handleRejection?/handleEndOfLifetime?/disposeInlineCompletions/onDidChangeInlineCompletions?/groupId?/yieldsToGroupIds?/excludesGroupIds?/displayName?/debounceDelayMs?/modelInfo?/onDidModelInfoChange?/setModelId?/providerOptions?/onDidProviderOptionsChange?/setProviderOption?/toString?） |
| LANG-085 | InlineCompletionContext | interface | 内联补全上下文（triggerKind/selectedSuggestionInfo/includeInlineEdits/includeInlineCompletions/requestIssuedDateTime/earliestShownDateTime/changeHint?） |
| LANG-086 | InlineCompletionTriggerKind | enum | 内联补全触发：Automatic=0/Explicit=1 |
| LANG-087 | SelectedSuggestionInfo | class | 已选建议信息（range/text/completionKind/isSnippetText/equals） |
| LANG-088 | InlineCompletionsDisposeReason | 类型 | 内联补全销毁原因：`{ kind: 'lostRace'\|'tokenCancellation'\|'other'\|'empty'\|'notTaken' }` |
| LANG-089 | InlineCompletionEndOfLifeReasonKind | enum | 生命周期结束原因：Accepted=0/Rejected=1/Ignored=2 |
| LANG-090 | LifetimeSummary | 类型 | 生命周期摘要（请求 UUID/部分接受/显示时长/编辑统计等大量遥测字段） |
| LANG-091 | IInlineCompletionChangeHint | interface | 内联补全变更提示（data?） |
| LANG-092 | IInlineCompletionModelInfo | interface | 内联补全模型信息（models/currentModelId） |
| LANG-093 | IInlineCompletionModel | interface | 内联补全模型（name/id） |
| LANG-094 | IInlineCompletionProviderOption | interface | 提供者选项（id/label/values/currentValueId） |
| LANG-095 | IInlineCompletionProviderOptionValue | interface | 提供者选项值（id/label） |
| LANG-096 | InlineCompletionWarning | interface | 内联补全警告（message/icon?） |
| LANG-097 | InlineCompletionHintStyle | enum | 提示样式：Code=1/Label=2 |
| LANG-098 | IInlineCompletionHint | interface | 内联补全提示（range/style/content） |
| LANG-099 | InlineCompletionCommand | 类型 | 内联补全命令（command/icon?） |
| LANG-100 | InlineCompletionProviderGroupId | 类型 | 提供者组 ID（string） |

### 4.6 Hover

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| LANG-101 | Hover | interface | 悬停信息（contents/range?/canIncreaseVerbosity?/canDecreaseVerbosity?） |
| LANG-102 | HoverProvider\<THover\> | interface | 悬停提供者（provideHover） |
| LANG-103 | HoverContext\<THover\> | interface | 悬停上下文（verbosityRequest?） |
| LANG-104 | HoverVerbosityRequest\<THover\> | interface | 悬停详细度请求（verbosityDelta/previousHover） |
| LANG-105 | HoverVerbosityAction | enum | 悬停详细度动作：Increase=0/Decrease=1 |

### 4.7 Signature Help

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| LANG-106 | SignatureHelp | interface | 签名帮助（signatures/activeSignature/activeParameter） |
| LANG-107 | SignatureInformation | interface | 签名信息（label/documentation?/parameters/activeParameter?） |
| LANG-108 | ParameterInformation | interface | 参数信息（label/documentation?） |
| LANG-109 | SignatureHelpResult | interface | 签名帮助结果（value: SignatureHelp），扩展 IDisposable |
| LANG-110 | SignatureHelpProvider | interface | 签名帮助提供者（signatureHelpTriggerCharacters?/signatureHelpRetriggerCharacters?/provideSignatureHelp） |
| LANG-111 | SignatureHelpContext | interface | 签名帮助上下文（triggerKind/triggerCharacter?/isRetrigger/activeSignatureHelp?） |
| LANG-112 | SignatureHelpTriggerKind | enum | 触发类型：Invoke=1/TriggerCharacter=2/ContentChange=3 |

### 4.8 Document Highlight / Linked Editing

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| LANG-113 | DocumentHighlight | interface | 文档高亮（range/kind?） |
| LANG-114 | DocumentHighlightKind | enum | 高亮类型：Text=0/Read=1/Write=2 |
| LANG-115 | DocumentHighlightProvider | interface | 文档高亮提供者（provideDocumentHighlights） |
| LANG-116 | MultiDocumentHighlight | interface | 多文档高亮（uri/highlights） |
| LANG-117 | MultiDocumentHighlightProvider | interface | 多文档高亮提供者（selector/provideMultiDocumentHighlights） |
| LANG-118 | LinkedEditingRanges | interface | 链接编辑范围（ranges/wordPattern?） |
| LANG-119 | LinkedEditingRangeProvider | interface | 链接编辑范围提供者（provideLinkedEditingRanges） |

### 4.9 References / Definition / Declaration / Implementation / TypeDefinition

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| LANG-120 | Location | interface | 位置（uri/range） |
| LANG-121 | LocationLink | interface | 位置链接（originSelectionRange?/uri/range/targetSelectionRange?） |
| LANG-122 | Definition | 类型 | 定义类型：Location\|Location[]\|LocationLink[] |
| LANG-123 | ReferenceContext | interface | 引用上下文（includeDeclaration） |
| LANG-124 | ReferenceProvider | interface | 引用提供者（provideReferences） |
| LANG-125 | DefinitionProvider | interface | 定义提供者（provideDefinition） |
| LANG-126 | DeclarationProvider | interface | 声明提供者（provideDeclaration） |
| LANG-127 | ImplementationProvider | interface | 实现提供者（provideImplementation） |
| LANG-128 | TypeDefinitionProvider | interface | 类型定义提供者（provideTypeDefinition） |

### 4.10 Document Symbol

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| LANG-129 | DocumentSymbol | interface | 文档符号（name/detail/kind/tags/containerName?/range/selectionRange/children?） |
| LANG-130 | SymbolKind | enum | 符号类型（26 值：File=0…TypeParameter=25） |
| LANG-131 | SymbolTag | enum | 符号标签：Deprecated=1 |
| LANG-132 | DocumentSymbolProvider | interface | 文档符号提供者（displayName?/provideDocumentSymbols） |

### 4.11 Code Action

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| LANG-133 | CodeAction | interface | 代码操作（title/command?/edit?/diagnostics?/kind?/isPreferred?/isAI?/disabled?/ranges?） |
| LANG-134 | CodeActionContext | interface | 代码操作上下文（markers/only?/trigger） |
| LANG-135 | CodeActionProvider | interface | 代码操作提供者（provideCodeActions/resolveCodeAction?） |
| LANG-136 | CodeActionProviderMetadata | interface | 代码操作提供者元数据（providedCodeActionKinds?/documentation?） |
| LANG-137 | CodeActionTriggerType | enum | 触发类型：Invoke=1/Auto=2 |
| LANG-138 | CodeActionList | interface | 代码操作列表（actions），扩展 IDisposable |

### 4.12 Formatting

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| LANG-139 | TextEdit | interface | 文本编辑（range/text/eol?） |
| LANG-140 | FormattingOptions | interface | 格式化选项（tabSize/insertSpaces） |
| LANG-141 | DocumentFormattingEditProvider | interface | 文档格式化提供者（displayName?/provideDocumentFormattingEdits） |
| LANG-142 | DocumentRangeFormattingEditProvider | interface | 范围格式化提供者（displayName?/provideDocumentRangeFormattingEdits/provideDocumentRangesFormattingEdits?） |
| LANG-143 | OnTypeFormattingEditProvider | interface | 输入时格式化提供者（autoFormatTriggerCharacters/provideOnTypeFormattingEdits） |

### 4.13 Link / Color / Selection Range / Folding

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| LANG-144 | ILink | interface | 链接（range/url?/tooltip?） |
| LANG-145 | ILinksList | interface | 链接列表（links/dispose?） |
| LANG-146 | LinkProvider | interface | 链接提供者（provideLinks/resolveLink?） |
| LANG-147 | IColor | interface | RGBA 颜色（red/green/blue/alpha，0-1 范围） |
| LANG-148 | IColorPresentation | interface | 颜色表示（label/textEdit?/additionalTextEdits?） |
| LANG-149 | IColorInformation | interface | 颜色信息（range/color） |
| LANG-150 | DocumentColorProvider | interface | 文档颜色提供者（provideDocumentColors/provideColorPresentations） |
| LANG-151 | SelectionRange | interface | 选区范围（range） |
| LANG-152 | SelectionRangeProvider | interface | 选区范围提供者（provideSelectionRanges） |
| LANG-153 | FoldingContext | interface | 折叠上下文（空接口） |
| LANG-154 | FoldingRange | interface | 折叠范围（start/end/kind?） |
| LANG-155 | FoldingRangeKind | class | 折叠范围类型类（value + 静态 Comment/Imports/Region/fromValue） |
| LANG-156 | FoldingRangeProvider | interface | 折叠范围提供者（onDidChange?/provideFoldingRanges） |

### 4.14 CodeLens / Inlay Hints

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| LANG-157 | CodeLens | interface | CodeLens（range/id?/command?） |
| LANG-158 | CodeLensList | interface | CodeLens 列表（lenses/dispose?） |
| LANG-159 | CodeLensProvider | interface | CodeLens 提供者（onDidChange?/provideCodeLenses/resolveCodeLens?） |
| LANG-160 | InlayHint | interface | Inlay Hint（label/tooltip?/textEdits?/position/kind?/paddingLeft?/paddingRight?） |
| LANG-161 | InlayHintLabelPart | interface | Inlay Hint 标签部分（label/tooltip?/command?/location?） |
| LANG-162 | InlayHintKind | enum | Inlay Hint 类型：Type=1/Parameter=2 |
| LANG-163 | InlayHintList | interface | Inlay Hint 列表（hints/dispose） |
| LANG-164 | InlayHintsProvider | interface | Inlay Hints 提供者（displayName?/onDidChangeInlayHints?/provideInlayHints/resolveInlayHint?） |

### 4.15 Semantic Tokens

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| LANG-165 | SemanticTokensLegend | interface | 语义 Token 图例（tokenTypes/tokenModifiers） |
| LANG-166 | SemanticTokens | interface | 语义 Token 数据（resultId?/data: Uint32Array） |
| LANG-167 | SemanticTokensEdit | interface | 语义 Token 编辑（start/deleteCount/data?） |
| LANG-168 | SemanticTokensEdits | interface | 语义 Token 编辑集（resultId?/edits） |
| LANG-169 | DocumentSemanticTokensProvider | interface | 文档语义 Token 提供者（onDidChange?/getLegend/provideDocumentSemanticTokens/releaseDocumentSemanticTokens） |
| LANG-170 | DocumentRangeSemanticTokensProvider | interface | 文档范围语义 Token 提供者（onDidChange?/getLegend/provideDocumentRangeSemanticTokens） |

### 4.16 Rename / New Symbol Name

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| LANG-171 | RenameProvider | interface | 重命名提供者（provideRenameEdits/resolveRenameLocation?） |
| LANG-172 | RenameLocation | interface | 重命名位置（range/text） |
| LANG-173 | Rejection | interface | 拒绝（rejectReason?） |
| LANG-174 | NewSymbolName | interface | 新符号名（newSymbolName/tags?） |
| LANG-175 | NewSymbolNamesProvider | interface | 新符号名提供者（supportsAutomaticNewSymbolNamesTriggerKind?/provideNewSymbolNames） |
| LANG-176 | NewSymbolNameTag | enum | 新符号名标签：AIGenerated=1 |
| LANG-177 | NewSymbolNameTriggerKind | enum | 触发类型：Invoke=0/Automatic=1 |

### 4.17 Workspace Edit / Command

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| LANG-178 | WorkspaceEdit | interface | 工作区编辑（edits: Array\<IWorkspaceTextEdit \| IWorkspaceFileEdit \| ICustomEdit\>） |
| LANG-179 | IWorkspaceTextEdit | interface | 工作区文本编辑（resource/textEdit/versionId/metadata?） |
| LANG-180 | IWorkspaceFileEdit | interface | 工作区文件编辑（oldResource?/newResource?/options?/metadata?） |
| LANG-181 | ICustomEdit | interface | 自定义编辑（resource/metadata?/undo/redo） |
| LANG-182 | WorkspaceEditMetadata | interface | 工作区编辑元数据（needsConfirmation/label/description?） |
| LANG-183 | WorkspaceFileEditOptions | interface | 文件编辑选项（overwrite?/ignoreIfNotExists?/ignoreIfExists?/recursive?/copy?/folder?/skipTrashBin?/maxSize?） |
| LANG-184 | Command | interface | 命令（id/title/tooltip?/arguments?） |
| LANG-185 | EditDeltaInfo | class | 编辑增量信息（linesAdded/linesRemoved/charsAdded/charsRemoved + fromText/tryCreate 静态方法） |

### 4.18 Comments（语言服务级）

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| LANG-186 | CommentThreadRevealOptions | interface | 评论线程显示选项（preserveFocus/focusReply） |
| LANG-187 | CommentAuthorInformation | interface | 评论作者信息（name/iconPath?） |
| LANG-188 | PendingCommentThread | interface | 待处理评论线程（range?/uri/uniqueOwner/isReply/comment） |
| LANG-189 | PendingComment | interface | 待处理评论（body/cursor） |

### 4.19 已弃用别名（languages.css / html / json / typescript）

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| LANG-190 | languages.css | 常量 | 已弃用，使用顶层 css 命名空间代替 |
| LANG-191 | languages.html | 常量 | 已弃用，使用顶层 html 命名空间代替 |
| LANG-192 | languages.json | 常量 | 已弃用，使用顶层 json 命名空间代替 |
| LANG-193 | languages.typescript | 常量 | 已弃用，使用顶层 typescript 命名空间代替 |

---

## 5. workers — Worker 命名空间（monaco.worker）

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| WORK-001 | IMirrorTextModel | interface | 镜像文本模型（version） |
| WORK-002 | IMirrorModel | interface | 镜像模型，扩展 IMirrorTextModel（uri/version/getValue()） |
| WORK-003 | IWorkerContext\<H\> | interface | Worker 上下文（host: H/getMirrorModels()） |
| WORK-004 | editor.createWebWorker | 方法 | 创建带模型同步的 Web Worker（见 EDITOR-206） |
| WORK-005 | MonacoWebWorker | interface | Web Worker 代理接口（见 EDITOR-207） |
| WORK-006 | IInternalWebWorkerOptions | interface | Web Worker 选项（见 EDITOR-208） |
| WORK-007 | Environment.getWorker | 功能特性 | 环境配置中的 Web Worker 工厂函数 |
| WORK-008 | Environment.getWorkerUrl | 功能特性 | 环境配置中的 Web Worker 脚本 URL 获取函数 |

---

## 6. basic-languages — 基础语言服务

### 6.1 CSS / SCSS / LESS（monaco.css）

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| BLANG-001 | cssDefaults | 常量 | CSS 语言服务默认配置（LanguageServiceDefaults） |
| BLANG-002 | scssDefaults | 常量 | SCSS 语言服务默认配置 |
| BLANG-003 | lessDefaults | 常量 | LESS 语言服务默认配置 |
| BLANG-004 | Options（CSS） | interface | CSS 选项（validate?/lint?/data?/format?） |
| BLANG-005 | ModeConfiguration（CSS） | interface | CSS 模式配置（completionItems/hovers/documentSymbols/definitions/references/documentHighlights/rename/colors/foldingRanges/diagnostics/selectionRanges/documentFormattingEdits/documentRangeFormattingEdits） |
| BLANG-006 | LanguageServiceDefaults（CSS） | interface | CSS 语言服务默认值（languageId/onDidChange/modeConfiguration/options/setOptions/setModeConfiguration/diagnosticsOptions[deprecated]/setDiagnosticsOptions[deprecated]） |
| BLANG-007 | CSSDataConfiguration | interface | CSS 数据配置（useDefaultDataProvider?/dataProviders?） |
| BLANG-008 | CSSDataV1 | interface | 自定义 CSS 数据（version/properties?/atDirectives?/pseudoClasses?/pseudoElements?） |

### 6.2 HTML / Handlebar / Razor（monaco.html）

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| BLANG-009 | htmlDefaults | 常量 | HTML 语言服务默认配置 |
| BLANG-010 | handlebarDefaults | 常量 | Handlebar 语言服务默认配置 |
| BLANG-011 | razorDefaults | 常量 | Razor 语言服务默认配置 |
| BLANG-012 | htmlLanguageService | 常量 | HTML 语言服务注册实例 |
| BLANG-013 | handlebarLanguageService | 常量 | Handlebar 语言服务注册实例 |
| BLANG-014 | razorLanguageService | 常量 | Razor 语言服务注册实例 |
| BLANG-015 | registerHTMLLanguageService | 方法 | 注册新的 HTML 语言服务 |
| BLANG-016 | Options（HTML） | interface | HTML 选项（format?/suggest?/data?） |
| BLANG-017 | ModeConfiguration（HTML） | interface | HTML 模式配置 |
| BLANG-018 | LanguageServiceDefaults（HTML） | interface | HTML 语言服务默认值 |
| BLANG-019 | HTMLDataConfiguration | interface | HTML 数据配置 |
| BLANG-020 | HTMLDataV1 | interface | 自定义 HTML 数据（version/tags?/globalAttributes?/valueSets?） |

### 6.3 JSON（monaco.json）

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| BLANG-021 | jsonDefaults | 常量 | JSON 语言服务默认配置 |
| BLANG-022 | DiagnosticsOptions（JSON） | interface | JSON 诊断选项（validate?/allowComments?/schemas?/enableSchemaRequest?/schemaValidation?/schemaRequest?/trailingCommas?/comments?） |
| BLANG-023 | ModeConfiguration（JSON） | interface | JSON 模式配置 |
| BLANG-024 | LanguageServiceDefaults（JSON） | interface | JSON 语言服务默认值 |
| BLANG-025 | IJSONWorker | interface | JSON Worker 接口（parseJSONDocument/getMatchingSchemas） |
| BLANG-026 | JSONSchema | interface | JSON Schema 定义 |
| BLANG-027 | getWorker（JSON） | 方法 | 获取 JSON Worker 工厂函数 |
| BLANG-028 | ASTNode（JSON） | 类型 | JSON AST 节点联合类型 |
| BLANG-029 | JSONDocument | 类型 | JSON 文档（root/getNodeFromOffset） |
| BLANG-030 | MatchingSchema | interface | 匹配的模式（node/schema） |
| BLANG-031 | SeverityLevel | 类型 | 严重级别：'error'\|'warning'\|'ignore' |

### 6.4 TypeScript / JavaScript（monaco.typescript）

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| BLANG-032 | typescriptDefaults | 常量 | TypeScript 语言服务默认配置 |
| BLANG-033 | javascriptDefaults | 常量 | JavaScript 语言服务默认配置 |
| BLANG-034 | typescriptVersion | 常量 | TypeScript 版本字符串 |
| BLANG-035 | getTypeScriptWorker | 方法 | 获取 TypeScript Worker 工厂函数 |
| BLANG-036 | getJavaScriptWorker | 方法 | 获取 JavaScript Worker 工厂函数 |
| BLANG-037 | LanguageServiceDefaults（TS） | interface | TS/JS 语言服务默认值（onDidChange/onDidExtraLibsChange/workerOptions/inlayHintsOptions/modeConfiguration/setModeConfiguration/getExtraLibs/addExtraLib/setExtraLibs/getCompilerOptions/setCompilerOptions/getDiagnosticsOptions/setDiagnosticsOptions/setWorkerOptions/setMaximumWorkerIdleTime/setEagerModelSync/getEagerModelSync/setInlayHintsOptions） |
| BLANG-038 | CompilerOptions | interface | TypeScript 编译器选项（~80+ 字段：target/module/strict/jsx/paths 等） |
| BLANG-039 | DiagnosticsOptions（TS） | interface | TS 诊断选项（noSemanticValidation?/noSyntaxValidation?/noSuggestionDiagnostics?/onlyVisible?/diagnosticCodesToIgnore?） |
| BLANG-040 | ModeConfiguration（TS） | interface | TS 模式配置（completionItems/hovers/documentSymbols/definitions/references/documentHighlights/rename/diagnostics/documentRangeFormattingEdits/signatureHelp/onTypeFormattingEdits/codeActions/inlayHints） |
| BLANG-041 | WorkerOptions（TS） | interface | TS Worker 选项（customWorkerPath?） |
| BLANG-042 | InlayHintsOptions（TS） | interface | TS Inlay Hints 选项（includeInlayParameterNameHints 等 7 项） |
| BLANG-043 | TypeScriptWorker | interface | TypeScript Worker 接口（getSyntacticDiagnostics/getSemanticDiagnostics/getSuggestionDiagnostics/getCompletionsAtPosition/getCompletionEntryDetails/getSignatureHelpItems/getQuickInfoAtPosition/getDocumentHighlights/getDefinitionAtPosition/getReferencesAtPosition/getNavigationTree/getFormattingEdits*/findRenameLocations/getRenameInfo/getEmitOutput/getCodeFixesAtPosition/provideInlayHints） |
| BLANG-044 | ModuleKind | enum | 模块类型：None=0/CommonJS=1/AMD=2/UMD=3/System=4/ES2015=5/ESNext=99 |
| BLANG-045 | JsxEmit | enum | JSX 输出：None=0/Preserve=1/React=2/ReactNative=3/ReactJSX=4/ReactJSXDev=5 |
| BLANG-046 | NewLineKind | enum | 换行类型：CarriageReturnLineFeed=0/LineFeed=1 |
| BLANG-047 | ScriptTarget | enum | 脚本目标：ES3=0…ESNext=99/JSON=100/Latest=99 |
| BLANG-048 | ModuleResolutionKind | enum | 模块解析：Classic=1/NodeJs=2 |
| BLANG-049 | Diagnostic（TS） | interface | TS 诊断（reportsUnnecessary?/reportsDeprecated?/source?/relatedInformation?） |
| BLANG-050 | DiagnosticMessageChain | interface | 诊断消息链（messageText/category/code/next?） |
| BLANG-051 | DiagnosticRelatedInformation | interface | 诊断相关信息（category/code/file/start/length/messageText） |
| BLANG-052 | EmitOutput | interface | 输出（outputFiles/emitSkipped/diagnostics?） |
| BLANG-053 | OutputFile | interface | 输出文件（name/writeByteOrderMark/text） |
| BLANG-054 | IExtraLib | interface | 额外库（content/version） |
| BLANG-055 | IExtraLibs | interface | 额外库映射 |
| BLANG-056 | MapLike\<T\> | interface | 映射类型 `[index: string]: T` |
| BLANG-057 | CompilerOptionsValue | 类型 | 编译器选项值类型 |

---

## 7. lsp — LSP 客户端（monaco.lsp）

| 编号 | 名称 | 类型 | 说明 |
|---|---|---|---|
| LSP-001 | MonacoLspClient | class | Monaco LSP 客户端，通过 IMessageTransport 连接 LSP 服务器，提供 createFeatures |
| LSP-002 | WebSocketTransport | class | WebSocket 传输层，扩展 BaseMessageTransport（connectTo/fromWebSocket/close/dispose） |
| LSP-003 | createTransportToWorker | 方法 | 创建到 Worker 的消息传输 |
| LSP-004 | createTransportToIFrame | 方法 | 创建到 iframe 的消息传输 |
| LSP-005 | IMessageTransport | interface | 消息传输接口（state/send/setListener/toString） |
| LSP-006 | BaseMessageTransport | class | 消息传输基类（setListener/send/_sendImpl/_dispatchReceivedMessage/_onConnectionClosed/log） |

---

## 附录：顶层 monaco 对象导出结构

`monaco`（即 .d.ts 中的 `editor_main` / `m`）导出以下子命名空间和类型：

| 导出 | 来源 | 说明 |
|---|---|---|
| monaco.editor | namespace editor | 编辑器命名空间 |
| monaco.languages | namespace languages | 语言服务命名空间 |
| monaco.worker | namespace worker | Worker 命名空间 |
| monaco.css | namespace register$3 | CSS/SCSS/LESS 基础语言 |
| monaco.html | namespace register$2 | HTML/Handlebar/Razor 基础语言 |
| monaco.json | namespace register$1 | JSON 基础语言 |
| monaco.typescript | namespace register | TypeScript/JavaScript 基础语言 |
| monaco.lsp | namespace index_d | LSP 客户端 |
| monaco.Uri / UriComponents | 顶层 | URI 类型 |
| monaco.Position / IPosition | 顶层 | 位置类型 |
| monaco.Range / IRange | 顶层 | 范围类型 |
| monaco.Selection / ISelection / SelectionDirection | 顶层 | 选区类型 |
| monaco.Token | 顶层 | Token 类型 |
| monaco.KeyCode / KeyMod | 顶层 | 键码/修饰符 |
| monaco.MarkerSeverity / MarkerTag | 顶层 | 标记严重级别/标签 |
| monaco.CancellationToken / CancellationTokenSource | 顶层 | 取消令牌 |
| monaco.Emitter / IEvent / IDisposable | 顶层 | 事件/可释放 |
| monaco.Environment / MonacoEnvironment | 顶层 | 环境配置 |
| monaco.IMarkdownString / MarkdownStringTrustedOptions | 顶层 | Markdown 字符串 |
| monaco.IKeyboardEvent / IMouseEvent / IScrollEvent | 顶层 | 事件类型 |
| monaco.ITrustedTypePolicy / ITrustedTypePolicyOptions | 顶层 | Trusted Types |
| monaco.Thenable | 顶层 | PromiseLike 别名 |

---

*文件生成依据：`reference/monaco-editor-0.56.0.d.ts`（10240 行），逐项来自源文件。*
