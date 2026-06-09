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

1. 将本仓库的 `template.yaml` 放到 GitHub 公开仓库
2. 在 SubStore「配置模板」中填入该文件的 Raw 链接
3. SubStore 会将你订阅中的节点自动注入到 `proxies` 列表，其余配置保持不变

### 方式二：YAML 覆写（`override.yaml`）

1. 将本仓库的 `override.yaml` 放到 GitHub 公开仓库
2. 在 SubStore 中使用支持 **YAML 覆写 / 配置覆写** 的入口导入此文件
3. **注意**：这是 YAML 覆写文件，**不能填到「脚本操作」里执行**

> 节点由 SubStore 自动从你的订阅注入，两个文件都不需要手动填写节点信息。

---

## 配置详解

### 基础设置

```yaml
mixed-port: 7890          # HTTP/SOCKS 混合端口
allow-lan: false          # 禁止局域网连接
mode: rule                # 规则模式
log-level: warning        # 日志级别
ipv6: false               # 关闭 IPv6
external-controller: 127.0.0.1:9090  # RESTful API 控制端口
secret: ""                # API 密钥（空 = 无认证）
unified-delay: true       # 统一延迟测试
tcp-concurrent: true      # TCP 并发连接
```

### hosts（仅 `override.yaml`）

`override.yaml` 内置了 `hosts` 配置，将 Google 关键服务域名固定到真实 IP：

```yaml
hosts:
  services.googleapis.cn: 142.250.80.227
  play.googleapis.com: 142.250.80.238
  android.clients.google.com: 142.250.80.238
  mtalk.google.com: 108.177.119.188
```

> 此配置可避免 DNS 污染导致 Google Play 商店无法正常下载/更新应用。

### DNS

- **增强模式**：`fake-ip`（Fake IP 模式），减少 DNS 泄露
- **Fake IP 范围**：`198.18.0.1/16`
- **Fake IP 过滤**：排除局域网域名、NTP 时间同步、微软连通性检测、**Google Play 下载域名**（`*.gvt1.com`、`dl.google.com`、`*.googleapis.cn` 等）
- **nameserver**：国内 DNS（Ali DNS、DNSPod），确保国内域名解析正确
- **nameserver-policy**（仅 `override.yaml`）：Steam 相关域名和 `geosite:cn` 走国内 DNS；**Google 域名** 和 `geosite:geolocation-!cn` 走 Google/Cloudflare DNS 代理

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
| hosts（Google 域名固定 IP） | ❌ | ✅ |
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
| 文件行数 | 79 行 | ~165 行 |

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

## 注意事项

- ⚠️ 两个 YAML 文件都是 **配置数据**，不是可执行脚本，不要填入 SubStore 的「脚本操作」
- ⚠️ `proxy-groups` 中使用了 `include-all: true`，SubStore 会自动将你订阅中的所有节点注入
- ⚠️ 如遇国内网站访问异常，检查 DNS 配置中的 `nameserver` 是否可达
- ⚠️ `external-controller` 监听 `127.0.0.1` 仅本地可访问，如需局域网访问请修改
