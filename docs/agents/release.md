# macOS 发版

从根目录 `Makefile` 组装：产物在 `.build/release/一键日历.app`（不是仓库根）。

## 常用命令

```bash
make build          # swift build -c release
make bundle         # 组装 .app + codesign 自签名 → .build/release/一键日历.app
make open           # bundle 后 open 该 .app（调试用这个，不要 make run）
make install        # bundle + ditto 到 /Applications 并重新签名
make verify-install # 校验 /Applications 里安装包的签名
make test           # swift test（需 macOS，带 SWIFT_BACKTRACE）
make lint           # 注释违规 + 测试隔离检查（零依赖）
make check          # = lint + test，提交前跑这个
make clean          # swift package clean（会清掉 .build/）
```

`make run` 会故意失败：裸 `swift run` 没有 app bundle，`Info.plist` 里的日历权限与 `LSUIElement` 不生效。请用 `make open`。

## 确认装上去的是不是新代码

怀疑「改了代码但行为没变」时，**先确认跑的是哪份二进制**，再怀疑代码。两个常见误判：

**1. 用 `strings | grep 类型名` 判断，会被优化骗。** Release 构建会裁掉类型名，但保留字符串字面量：

```
$ strings .build/release/一键日历 | grep -c CalendarLookupAuthority
0                                    ← 类型名被优化掉了，不代表是旧代码
$ strings .build/release/一键日历 | grep -c refusedNoAuthority
1                                    ← 字面量还在，代码是新的
```

要验证新代码在不在，挑一个**字符串字面量**（日志文案、localized key、枚举原始值），不要用类型名或函数名。

**2. 用哈希对比签名前后的二进制，会被签名骗。** `codesign` 会重写 Mach-O，大小和哈希都会变：

```
签名前  4798672 字节  b14d3357...
签名后  4770912 字节  85d638a5...   ← 正常行为，不是安装失败
```

要比哈希，就在**同一阶段**比（都是签名前，或都是签名后）。

### 正确的判据

- 看产物 mtime：`ls -la .build/out/Products/Release/一键日历`（`.build/release` 是符号链接，指向它）
- 或比**同一阶段**的哈希
- 构建耗时 0.4 秒且源码未变时，产物不变是**正确行为**；源码变了仍 0.4 秒且哈希不变，才可疑

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
