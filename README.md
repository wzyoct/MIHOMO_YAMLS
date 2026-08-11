# MIHOMO_YAMLS

Mihomo（原 Clash Meta）代理客户端的 [SubStore](https://github.com/sub-store-org/Sub-Store) 配置仓库。实现 **「国外流量走代理，国内流量走直连」** 的分流策略。

## 文件说明

| 文件 | 类型 | 用途 |
|------|------|------|
| `template.yaml` | SubStore 配置模板 | 精简版，在 SubStore「配置模板」中填入 Raw 链接；SubStore 自动注入节点 |
| `override.yaml` | YAML 覆写文件 | 完整版，用于支持 YAML 覆写 / 配置覆写的入口（**不是快捷脚本**） |

两个文件的核心策略一致：国外走代理、国内走直连。`override.yaml` 比 `template.yaml` 更完善，详见下方差异对照。

---

## 使用方法

### 方式一：配置模板（`template.yaml`）

1. 在 SubStore「配置模板」中填入 [`template.yaml` Raw 链接](https://raw.githubusercontent.com/wzyoct/MIHOMO_YAMLS/main/template.yaml)
2. 保存后由 SubStore 自动注入订阅节点
3. 重新生成订阅并导入 Mihomo 客户端

### 方式二：YAML 覆写（`override.yaml`）

1. 在 SubStore 中使用支持 **YAML 覆写 / 配置覆写** 的入口导入 [`override.yaml` Raw 链接](https://raw.githubusercontent.com/wzyoct/MIHOMO_YAMLS/main/override.yaml)
2. 重新生成订阅并导入 Mihomo 客户端
3. **注意**：这是 YAML 覆写文件，**不能填到「脚本操作」里执行**

> 节点由 SubStore 自动从你的订阅注入，两个文件都不需要手动填写节点信息。

---

## 配置详解

### 基础设置

```yaml
mixed-port: 7890          # HTTP/SOCKS 混合端口
allow-lan: false          # 不允许局域网访问代理端口
mode: rule                # 规则模式
log-level: warning        # 日志级别
ipv6: false               # 关闭 IPv6
external-controller: 127.0.0.1:9090  # RESTful API 控制端口
secret: ""                # API 密钥（空 = 无认证）
unified-delay: true       # 统一延迟测试
tcp-concurrent: true      # TCP 并发连接
```

### DNS

- **增强模式**：`fake-ip`（Fake IP 模式），减少 DNS 泄露
- **Fake IP 范围**：`198.18.0.1/16`
- **Fake IP 过滤**：排除局域网域名、NTP 时间同步、微软连通性检测、**Google Play 下载域名**（`*.gvt1.com`、`*.dl.google.com`、`*.googleapis.cn` 等）
- **nameserver**：国内 DNS（Ali DNS、DNSPod），确保国内域名解析正确
- **nameserver-policy**（仅 `override.yaml`）：Steam 相关域名和 `geosite:cn` 走国内 DNS；**Google 域名** 和 `geosite:geolocation-!cn` 走 Google/Cloudflare DNS 代理
- **监听范围**：默认仅监听 `127.0.0.1:1053`，避免向局域网暴露 DNS 服务。路由器或需要为其他设备提供 DNS 的用户可改为 `0.0.0.0:1053`，并应同时配置防火墙访问规则。

### 域名嗅探（仅 `override.yaml`）

`override.yaml` 开启 TLS / HTTP 嗅探，帮助识别系统 DownloadManager 发起的 Google Play 下载流量的真实域名：

```yaml
sniffer:
  enable: true
  sniffing:
    - tls
    - http
```

### 代理组

| 代理组 | 类型 | 说明 |
|--------|------|------|
| 🚀 代理 | select | 顶层入口，可选择「自动/故障转移」或「手动选择」 |
| ⚡ 自动最快 / 🔄 故障转移 | url-test / fallback | 自动测速选最快 / 故障转移 |
| ✋ 手动选择 | select | 手动指定节点 |

- `template.yaml` 使用 `url-test`（自动最快，tolerance=50）
- `override.yaml` 使用 `fallback`（故障转移，lazy=true，max-failed-times=3）

### 路由规则

规则从上到下匹配，命中即停止：

1. **局域网 / 私有地址** → `DIRECT`（直连）
2. **Google 服务**（仅 `override.yaml`）：CDN 下载域名（`xn--ngstr-lra8j.com`、`clientservices.googleapis.com`、`update.googleapis.com`）走 `DIRECT` 直连，其余浏览/API 走 `🚀 代理`
3. **Steam 相关**（仅 `override.yaml`）：下载服务器直连，其余走代理
4. **国内网站 / IP** → `DIRECT`（通过 GEOSITE:CN / GEOIP:CN）
5. **其余所有流量** → `🚀 代理`

---

## 两个文件差异对照

| 配置项 | `template.yaml` | `override.yaml` |
|--------|:---:|:---:|
| 基础设置 | ✅ | ✅ |
| DNS - use-hosts / use-system-hosts | ❌ | ✅ |
| DNS - fake-ip-filter-mode | ❌ | ✅ blacklist |
| DNS - fake-ip-filter 条目 | 4 条 | 27 条（含 Google Play 下载域名 + CDN 域名） |
| DNS - default-nameserver | ❌ | ✅ |
| DNS - proxy-server-nameserver | ❌ | ✅ |
| DNS - nameserver-policy | ❌ | ✅（Steam + Google + geosite 分流） |
| 域名嗅探（sniffer） | ❌ | ✅（TLS + HTTP） |
| 代理组 - 自动模式 | url-test（⚡ 自动最快） | fallback（🔄 故障转移） |
| Google 服务路由规则 | ❌ | ✅（CDN 下载直连 + GEOSITE:google 兜底代理） |
| Steam 路由规则 | ❌ | ✅（下载直连 + GEOSITE） |
| CIDR 局域网规则 | GEOIP 一条 | IP-CIDR 五段 + GEOIP |
| 文件行数 | 79 行 | ~164 行 |

### 建议

- 追求简洁、快速 → 用 `template.yaml`
- 需要更完善的 DNS 分流、Google Play 商店优化、Steam 优化、故障转移 → 用 `override.yaml`
- **Android 手机用户强烈建议使用 `override.yaml`**，已针对 Google Play 下载「准备中」问题进行专项优化

---

## 文件结构

```
MIHOMO_YAMLS/
├── README.md         # 本文档
├── template.yaml     # SubStore 配置模板（精简版）
└── override.yaml     # YAML 覆写文件（完整版）
```

## 维护与验证

- 每次修改 YAML 后可在仓库根目录运行 `pwsh ./scripts/validate-config.ps1`，检查代理组名称与规则/DNS 引用是否一致。
- GitHub Actions 会在 Pull Request 和 `main` 分支的配置改动上解析 YAML 格式并执行同样的引用检查；发布前仍应在实际的 SubStore 与 Mihomo 客户端中导入测试。
- 变更详情记录在 [CHANGELOG.md](CHANGELOG.md)。提交问题时，请附上客户端、Mihomo 内核版本和已脱敏的错误日志。

## 注意事项

- ⚠️ 两个 YAML 文件都是 **配置数据**，不是可执行脚本，不要填入 SubStore 的「脚本操作」
- ⚠️ `proxy-groups` 中使用了 `include-all: true`，SubStore 会自动将你订阅中的所有节点注入
- ⚠️ 如遇国内网站访问异常，检查 DNS 配置中的 `nameserver` 是否可达
- ⚠️ DNS 默认监听 `127.0.0.1:1053`，仅本机可访问；路由器或局域网 DNS 场景需改为 `0.0.0.0:1053` 并限制防火墙访问范围
- ⚠️ `external-controller` 监听 `127.0.0.1` 仅本地可访问，如需局域网访问请修改
- ⚠️ `override.yaml` 的 `nameserver-policy` 中使用了 emoji 代理组名称（`#🚀 代理`），如果客户端不支持 emoji 解析，请将代理组名称和所有引用改为纯 ASCII 名称

---

## 故障排除

### Google Play 下载卡在「准备中」

这是最常见的问题，通常由 DNS 解析或路由导致：

1. **确认使用 `override.yaml`** — `template.yaml` 没有针对 Google Play 的优化
2. **检查 fake-ip-filter** — 确保 `*.gvt1.com`、`*.dl.google.com`、`*.googleapis.cn` 等域名在 fake-ip-filter 列表中
3. **检查 DNS 可达性** — 在终端运行 `nslookup dl.google.com 223.5.5.5`，确认国内 DNS 能正常解析
4. **清除应用数据** — 进入手机「设置 → 应用 → Google Play 商店」清除缓存和数据，然后重试
5. **重启 Mihomo** — 有时候需要重启客户端让配置生效

### 国内网站无法访问

1. 检查 `nameserver` 配置中的 DNS 服务器是否可达（`223.5.5.5`、`119.29.29.29`）
2. 确认路由规则中 `GEOSITE,cn` 和 `GEOIP,CN` 在 `MATCH` 规则之前
3. 尝试关闭 `fake-ip` 模式测试是否为 Fake IP 导致的问题

### DNS 解析失败

1. 检查 `listen: 127.0.0.1:1053` 端口是否被占用
2. 确认系统 DNS 设置指向了 Mihomo 的 DNS 端口（`127.0.0.1:1053`）
3. 尝试更换 `nameserver` 中的 DNS 服务器地址

### 代理连接缓慢

1. 在 Mihomo 面板中执行延迟测试，选择延迟最低的节点
2. 如果使用 `override.yaml` 的故障转移模式，检查 `max-failed-times` 设置
3. 确认 `tcp-concurrent: true` 已开启

---

## 常见问题（FAQ）

### 两个文件应该选哪个？

| 场景 | 推荐文件 |
|------|----------|
| 快速上手、轻量使用 | `template.yaml` |
| Android 手机用户 | `override.yaml`（Google Play 优化） |
| 需要 Steam 下载直连 | `override.yaml` |
| 需要故障转移（节点挂了自动切换） | `override.yaml` |
| 不确定选哪个 | `override.yaml`（功能更完善） |

### 如何更新配置？

1. 在 SubStore 中重新拉取 Raw 链接即可（配置模板模式）
2. YAML 覆写模式下，重新导入最新的 `override.yaml` 文件
3. 更新后建议重启 Mihomo 客户端

### 这些配置支持哪些客户端？

本配置基于 **Mihomo（原 Clash Meta）** 内核，适用于所有使用 Mihomo 内核的客户端：

- **移动端 / 桌面端**：使用 Mihomo 内核的客户端；SubStore 负责生成和管理订阅
- **路由器**：OpenClash（OpenWrt）等使用 Mihomo 内核的方案

> ⚠️ 不适用于 Clash for Windows 等已停止维护的客户端。

### 配置中的 emoji 代理组名称会导致问题吗？

大部分现代 Mihomo 客户端支持 emoji。如果你的客户端出现解析错误，将 `override.yaml` 中所有 `🚀 代理`、`🔄 故障转移`、`✋ 手动选择` 替换为纯 ASCII 名称（如 `proxy`、`fallback`、`manual`）。

### 节点从哪里来？

两个 YAML 文件都使用了 `include-all: true`，**节点由 SubStore 自动从你的订阅中注入**，不需要在配置文件中手动填写。

---

## 兼容性说明

| 项目 | 要求 |
|------|------|
| Mihomo 内核 | ≥ 1.18.0（使用内置 GEOSITE/GEOIP 规则） |
| SubStore | 最新版本 |
| OpenClash | ≥ 0.46.0（支持 YAML 覆写） |

### 已知限制

- `nameserver-policy` 中的 emoji 标签在极少数旧版客户端中可能不被识别
- `fake-ip` 模式下部分应用（如某些银行 App）可能需要将其域名加入 `fake-ip-filter`
- GEOSITE/GEOIP 数据库需要定期更新才能保证规则准确
