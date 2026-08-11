# 更新日志

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 的记录方式，并使用 [Semantic Versioning](https://semver.org/lang/zh-CN/) 管理版本。

## [Unreleased]

## [1.0.0] - 2026-08-11

### 新增

- 提供 `template.yaml`：适用于 SubStore 配置模板的精简分流配置。
- 提供 `override.yaml`：包含 DNS 分流、域名嗅探、Google Play 与 Steam 优化的完整覆写配置。
- 提供本地配置语义校验脚本与 GitHub Actions 自动检查。
- 提供 MIT 许可证。

### 变更

- README 补充可直接导入的 Raw 链接、验证流程与项目维护说明。

### 修复

- Google Play 下载域名使用真实 DNS，并将中国大陆 CDN 下载流量设为直连。
- 为 Tailscale 和局域网地址补充直连规则。

[Unreleased]: https://github.com/wzyoct/MIHOMO_YAMLS/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/wzyoct/MIHOMO_YAMLS/releases/tag/v1.0.0
