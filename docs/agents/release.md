# macOS 发版

从根目录 `Makefile` 组装：产物在 `.build/release/一键日历.app`（不是仓库根）。

## 常用命令

```bash
make build          # swift build -c release
make bundle         # 组装 .app + codesign 自签名 → .build/release/一键日历.app
make open           # bundle 后 open 该 .app（调试用这个，不要 make run）
make install        # bundle + ditto 到 /Applications 并重新签名
make verify-install # 校验 /Applications 里安装包的签名
make test           # swift test（需 macOS）
make clean          # swift package clean（会清掉 .build/）
```

`make run` 会故意失败：裸 `swift run` 没有 app bundle，`Info.plist` 里的日历权限与 `LSUIElement` 不生效。请用 `make open`。

## 发布流程

1. 改源码 → 在 macOS 上 `swift build` + `swift test`（或 `make test`）
2. 更新根目录 `Info.plist` 的 `CFBundleShortVersionString` 和 `CFBundleVersion`（`make bundle` 时会 `cp` 进 bundle）
3. `make install`（或至少 `make bundle` 确认产物）
4. 打包 zip（路径指向 `.build` 下的 app；可用 `-j` 让 zip 内顶层仍是 `一键日历.app`）:

   ```bash
   cd .build/release && zip -X -r ../../releases/YijianRili-v<版本>-macOS.app.zip 一键日历.app && cd ../..
   ```

5. 写 `releases/v<版本>.md`
6. `git add Info.plist` + commit + push。**不要跟踪任何 app bundle 内文件**——根目录 `Info.plist` 才是源文件；发版二进制只进 GitHub Releases
7. `gh release create v<版本> releases/YijianRili-v<版本>-macOS.app.zip --notes-file releases/v<版本>.md`
8. 制作 dmg：hdiutil UDRW → AppleScript 设 Finder 布局 → hdiutil convert UDZO（细节见 `retrospectives/v1.4.0.md`）
9. `gh release upload v<版本> releases/YijianRili-v<版本>-macOS.dmg`

**dmg 文件名必须用纯 ASCII**（`YijianRili-v<版本>-macOS.dmg`），`gh upload` 会吞掉中文字符。
