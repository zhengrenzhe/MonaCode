# MonaCode

MonaCode 是面向 Apple 平台、使用 Swift 原生开发的代码编辑器组件，以
**monaco-editor@0.56.0** 的行为和公开接口作为对标基线。

- 当前发布目标：**arm64 macOS**
- iOS / iPadOS：后续版本范围
- 对标范围：编辑器组件 + LSP 的 API / 功能侧面

对标基准与进度真源（唯一真源，不再使用任何过程/治理文档）：

- `reference/monaco-editor-0.56.0.d.ts` — 完整公开接口
- `reference/monaco-editor-0.56.0.editor.api.d.ts` — editor API 面
- `PROGRESS.md` — **进度唯一真源**（对照 monaco 501 条 checklist 的复盘 + 当前真实状态 + 下一步）

## 构建

```bash
swift build                            # 库 + sample
swift run sample-macOS-host            # 跑 sample host 窗口
swift test                            # 全量测试
```

## 当前真实状态（2026-08-22 复盘，非任何旧 verdict）

- **已实现核心**：Piece Tree 文本缓冲、ECMAScript RegExp、Core Text shaping、命令分发器（type / deleteLeft / cursor*）、多光标 input barrier、事务 gateway、AppKit AX 合规。
- **Broken**：渲染位图按 1× 分配、无视 backingScaleFactor → Retina 文字模糊；编辑路径代码已通但运行期未跑通。
- **Stub**：LSP 仅有协议编解码 / 会话状态机，无 transport、无真实语言服务器；语法高亮仅 plain-text 回退，无 Monarch tokenizer；无 completion / diagnostics / hover。

下一步优先级：先跑通“清晰 + 可编辑”的编辑器基线，再补语言层。
