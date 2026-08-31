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

## VPS 部署与 Mihomo 对接

本节记录一套已经实际验证过的部署流程：Debian 12 amd64、Docker Engine、`xream/sub-store` 和 Caddy HTTPS。它适合将 SubStore 部署在自己的 VPS 上，再用本仓库的 YAML 生成 Mihomo 配置。

本仓库不需要复制到 VPS。SubStore 直接读取 GitHub Raw 链接即可。文档中的以下占位符需要替换为自己的值：

相关官方文档：[Docker Engine for Debian](https://docs.docker.com/engine/install/debian/)、[SubStore Docker](https://hub.docker.com/r/xream/sub-store) 和 [Caddy 安装](https://caddyserver.com/docs/install)。

| 占位符 | 含义 |
|--------|------|
| `sub-store.example.com` | SubStore 使用的域名 |
| `VPS_IP` | VPS 公网 IPv4 地址 |
| `SUBSTORE_PATH` | SubStore 后端随机路径，只使用字母、数字和下划线 |
| `SSH_PORT` | VPS 实际 SSH 端口，不一定是 22 |

公开存档只使用上述占位符。不要把真实 VPS 地址、SubStore 后端路径、机场订阅链接、Token、密码、证书或私钥写入仓库；部署凭据应保存在密码管理器中。Git 提交建议使用 GitHub 提供的 `noreply` 邮箱：

```bash
git config user.email "你的 GitHub noreply 邮箱"
```

仓库的 `.gitignore` 已覆盖常见的环境变量、证书、密钥和本地备份文件，但忽略规则不能替代提交前检查。

### 部署后的结构

```text
Mihomo 客户端
    │ 远程导入最终配置链接
    ▼
https://sub-store.example.com
    │ Caddy HTTPS 反向代理
    ▼
127.0.0.1:3001  SubStore Docker 容器
    │ 读取机场订阅与本仓库 YAML
    ▼
最终 Mihomo 配置
```

### 前置检查

1. 在 DNS 服务商处添加 A 记录：`sub-store.example.com` → `VPS_IP`。
2. 如果没有配置 IPv6，不要添加指向错误地址的 AAAA 记录。
3. 在 VPS 服务商的防火墙/安全组中放行 TCP `80` 和 `443`。
4. 保留当前 SSH 端口的放行规则，并确认实际 SSH 端口：

```bash
ss -lntp | awk '$4 ~ /:[0-9]+$/ && $7 ~ /sshd/ {print}'
```

检查 DNS 和 80/443 是否被已有服务占用：

```bash
getent ahostsv4 sub-store.example.com | awk '{print $1}' | sort -u
ss -ltnp | awk '$4 ~ /:(80|443)$/ {print}'
```

DNS 结果应包含 VPS 公网 IP。80 或 443 已被 Nginx、宝塔、1Panel 等服务占用时，应使用已有反向代理，不要再启动第二个服务抢占端口。

### 1. 在 Debian 12 安装 Docker

以下命令适用于以 `root` 登录的 Debian 12。非 root 用户请在命令前加 `sudo`。Docker 官方仓库方式会同时安装 Docker Compose 插件：

```bash
apt update
apt install -y ca-certificates curl openssl

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
  -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
```

验证 Docker 服务和 Compose：

```bash
systemctl --no-pager --full status docker
docker --version
docker compose version
docker run --rm hello-world
```

最后一条命令应输出 `Hello from Docker!`。如果系统已有 `docker.io`、`containerd` 或 `runc` 等发行版软件包，应先确认是否与 Docker 官方软件包冲突，再按 Docker 官方文档处理，不要盲目删除生产环境中的容器数据。

### 2. 启动 SubStore 容器

使用绑定目录保存数据，容器删除或更新时不会丢失 SubStore 数据。后端路径建议每台服务器随机生成，并保存到密码管理器中：

```bash
mkdir -p /root/sub-store-data
SUBSTORE_PATH="/ss_$(openssl rand -hex 12)"
printf '请保存这个 SubStore 后端路径: %s\n' "$SUBSTORE_PATH"
```

`SUBSTORE_PATH` 只是当前 SSH 会话中的 shell 变量。重新登录 VPS 后，需要先将它设置为之前保存的实际路径，或者直接把命令中的 `${SUBSTORE_PATH}` 替换成实际路径。

使用上一步输出的路径启动容器：

```bash
docker run -d \
  --name sub-store \
  --restart=unless-stopped \
  -e "SUB_STORE_FRONTEND_BACKEND_PATH=$SUBSTORE_PATH" \
  -p 127.0.0.1:3001:3001 \
  -v /root/sub-store-data:/opt/app/data \
  xream/sub-store:latest
```

`latest` 适合快速部署；需要可重复部署时，应将镜像替换为经过验证的固定版本标签或 digest，并在更新前保留数据备份。

验证容器和后端接口：

```bash
docker ps --filter name=sub-store
curl -fsS "http://127.0.0.1:3001${SUBSTORE_PATH}/api/utils/env"
```

健康检查返回 JSON 且包含以下字段时，说明后端正常：

```json
{
  "status": "success",
  "data": {
    "backend": "Node",
    "version": "..."
  }
}
```

`-p 127.0.0.1:3001:3001` 很重要：它只允许 VPS 本机访问，不要改成 `-p 3001:3001` 或 `-p 0.0.0.0:3001:3001`，避免把管理后端暴露到公网。

### 3. 使用 Caddy 配置 HTTPS

Caddy 适合单域名反向代理，配置域名后会自动申请和续期证书。先安装官方 Debian 软件包：

```bash
apt install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg

curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
  | gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
  -o /etc/apt/sources.list.d/caddy-stable.list

chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg
chmod o+r /etc/apt/sources.list.d/caddy-stable.list

apt update
apt install -y caddy
```

备份默认配置并写入反向代理配置：

```bash
cp -a /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup
printf '%s\n' 'sub-store.example.com {' '    reverse_proxy 127.0.0.1:3001' '}' > /etc/caddy/Caddyfile
```

验证并加载配置：

```bash
caddy fmt --overwrite /etc/caddy/Caddyfile
caddy validate --config /etc/caddy/Caddyfile
systemctl enable --now caddy
systemctl reload caddy
systemctl --no-pager --full status caddy
```

查看证书申请日志：

```bash
journalctl -u caddy -n 100 --no-pager
```

看到 `certificate obtained successfully` 表示证书已签发。证书申请失败时，优先检查 DNS 是否指向当前 VPS，以及服务商防火墙是否放行 TCP `80` 和 `443`。

通过域名检查 SubStore 后端：

```bash
curl -fsS "https://sub-store.example.com${SUBSTORE_PATH}/api/utils/env"
```

### 4. 打开 SubStore 前端

在浏览器打开以下地址，将域名和后端路径替换为自己的值：

```text
https://sub-store.example.com/?api=https://sub-store.example.com/SUBSTORE_PATH
```

例如，`SUBSTORE_PATH` 如果是 `/ss_abc123`，最终地址就是：

```text
https://sub-store.example.com/?api=https://sub-store.example.com/ss_abc123
```

下面这个地址是后端健康检查接口，返回 JSON 是正常的，不是前端页面：

```text
https://sub-store.example.com/SUBSTORE_PATH/api/utils/env
```

HTTPS 部署完成后，不再需要 SSH 隧道。SubStore 官方 Docker 文档中的前端访问方式也是通过 `?api=` 指定后端地址。

---

### 5. 在 SubStore 中接入机场订阅

全部操作在 SubStore 网页中完成：

1. 进入「订阅管理」，点击「添加」或 `+`。
2. 填写订阅名称，例如 `机场主订阅`。
3. 将机场订阅链接填入远程订阅 URL。
4. 保存并更新订阅。
5. 预览订阅，确认能看到节点。

机场订阅 URL 通常包含账号凭据，不要提交到 GitHub，也不要发给他人。

### 6. 将本仓库 YAML 接入 Mihomo 配置

推荐使用功能更完整的 `override.yaml`：

```text
https://raw.githubusercontent.com/wzyoct/MIHOMO_YAMLS/main/override.yaml
```

在 SubStore 中：

1. 进入「文件」，点击「新建」。
2. 选择「Mihomo 配置」或「Clash.Meta 配置」。
3. 填写配置名称，例如 `mickey-mihomo`。
4. 来源类型选择「订阅」，来源选择刚才保存的机场订阅。
5. 在该 Mihomo 配置页面的「覆写 / 配置覆写」字段填入上面的 Raw 链接。
6. 保存并预览。

这里使用的是 Mihomo 配置页面中的覆写字段，不是左侧独立的「脚本操作」页面。`override.yaml` 是 YAML 配置数据，不是 JavaScript 脚本。

预览时应确认：

- 能看到机场节点；
- 存在 `🚀 代理`、`🔄 故障转移` 和 `✋ 手动选择`；
- 没有 YAML 解析错误；
- 规则中包含国内直连和最终代理兜底规则。

如果只需要精简配置，也可以在「配置模板」中使用：

```text
https://raw.githubusercontent.com/wzyoct/MIHOMO_YAMLS/main/template.yaml
```

### 7. 生成最终订阅并导入客户端

在已保存的 Mihomo 配置上点击「分享」「导出」或分享图标，选择 `Mihomo` / `Clash.Meta`，复制 SubStore 生成的远程订阅链接。

最终链接通常类似：

```text
https://sub-store.example.com/SUBSTORE_PATH/api/file/...
```

不要把机场原始链接或 `override.yaml` Raw 链接直接当作最终客户端订阅。客户端应导入 SubStore 生成的链接，这样订阅更新和 YAML 更新可以统一管理。

在 Mihomo Party、Clash Verge Rev、OpenClash 或其他 Mihomo 客户端中，进入「配置 / Profiles / 订阅管理」：

1. 添加远程配置。
2. 粘贴 SubStore 生成的链接。
3. 保存并更新。
4. 选择该配置作为当前配置。
5. 在 `✋ 手动选择` 中选择节点，或使用 `🔄 故障转移`。

### 8. 日常更新与备份

机场订阅更新：在 SubStore 的「订阅管理」中更新，客户端再更新最终链接。

本仓库 YAML 更新：SubStore 中重新拉取 Raw 链接，然后客户端更新最终链接。

更新 SubStore 镜像时，必须使用与首次启动相同的后端路径和数据目录：

```bash
docker pull xream/sub-store:latest
docker stop sub-store
docker rm sub-store

# 重新执行“启动 SubStore 容器”中的 docker run，
# 保持 SUB_STORE_FRONTEND_BACKEND_PATH 和数据目录不变。
```

删除容器不会删除 `/root/sub-store-data` 绑定目录，但不要删除该目录。

备份本地数据：

```bash
tar -C /root -czf "/root/sub-store-data-$(date +%F).tar.gz" sub-store-data
chmod 600 /root/sub-store-data-*.tar.gz
```

备份文件可能包含订阅信息和配置凭据，只保存到受控位置，不要上传到公开仓库。

### 9. 常用检查与故障排除

查看容器：

```bash
docker ps --filter name=sub-store
docker logs --tail 100 sub-store
```

查看 Caddy：

```bash
systemctl --no-pager --full status caddy
journalctl -u caddy -n 100 --no-pager
```

检查监听端口：

```bash
ss -ltnp | awk '$4 ~ /:(80|443|3001)$/ {print}'
```

预期结果是：Caddy 监听 80/443，SubStore 只监听 `127.0.0.1:3001`。

常见现象：

| 现象 | 优先检查 |
|------|----------|
| 浏览器无法申请证书 | DNS、服务商防火墙、TCP 80/443 |
| Caddy 返回 502 | `docker ps`、SubStore 日志、`curl http://127.0.0.1:3001...` |
| 访问后看到后端 JSON | 访问的是 `/api/utils/env`，前端应使用根路径加 `?api=` |
| 预览没有节点 | 机场订阅是否过期、订阅更新日志、输入格式 |
| YAML 解析失败 | 是否把 YAML 放进了「脚本操作」，或客户端内核版本过旧 |
| SSH、Reality、网页同时短暂中断 | 检查 VPS 重启记录、内核日志、网卡状态和服务商网络事件 |

网络故障排查时不要直接执行 `iptables -F`、`nft flush ruleset` 或关闭防火墙。SSH 端口也不要默认假设为 22，应使用实际监听端口，例如：

```powershell
Test-NetConnection VPS_IP -Port SSH_PORT
```

如果 SSH、Reality 和其他公网服务同时不可达，而 VPS 没有重启、资源正常且内核没有网卡异常，应把故障时间和 VPS IP 提交给服务商排查宿主机或上游网络。

### 10. 最终检查清单

- [ ] DNS A 记录指向 VPS，错误 AAAA 记录已删除。
- [ ] 服务商防火墙放行 TCP 80/443 和实际 SSH 端口。
- [ ] Docker、Compose、SubStore 容器状态正常。
- [ ] SubStore 数据目录已绑定到宿主机。
- [ ] SubStore 后端只监听 `127.0.0.1:3001`。
- [ ] Caddy 已成功签发 HTTPS 证书。
- [ ] SubStore 前端通过 `https://域名/?api=https://域名/随机路径` 打开。
- [ ] SubStore 中机场订阅预览有节点。
- [ ] Mihomo 配置使用了本仓库的 YAML 覆写链接。
- [ ] 客户端导入的是 SubStore 生成的最终链接。

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
