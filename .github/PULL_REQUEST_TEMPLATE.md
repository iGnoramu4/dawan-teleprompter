## 变更说明

<!-- 说明为什么改，而不是只列改了什么。关联 Issue：Fixes #... -->

## 变更类型

- [ ] 修复
- [ ] 新功能
- [ ] 重构 / 性能
- [ ] 文档 / 构建 / CI
- [ ] 其他

## 自检

- [ ] `dart format --output=none --set-exit-if-changed .`
- [ ] `dart analyze --fatal-infos --fatal-warnings .`（apps/app 与改动的 packages）
- [ ] `dart run tool/check_imports.dart`
- [ ] `flutter test --coverage` 且覆盖率 ≥ 70%
- [ ] `dart run tool/license_scan.dart`
- [ ] 涉及 UI 的改动附截图或录屏
- [ ] 涉及真机行为但未实测的，已在测试记录中标注

## 兼容性与数据

<!-- 是否改包名、数据库、文件格式、协议或私有目录？是否影响升级与旧数据？ -->

## 备注

<!-- 已知限制、后续工作、需要 reviewer 重点关注的地方 -->
