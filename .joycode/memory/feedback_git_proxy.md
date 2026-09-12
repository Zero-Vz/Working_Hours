---
name: git_proxy_not_needed
description: 用户确认无需代理即可直接推送GitHub
type: feedback
---

规则：不要为 git 配置代理（http.proxy / https.proxy）。用户确认可以直接推送 GitHub，无需代理。
**Why:** 之前配置 127.0.0.1:10808 代理后反而导致推送失败（TLS 错误、连接超时），取消代理后直连成功。
**How to apply:** 遇到 git push 失败时，不要建议配置代理，而是检查是否有残留代理配置并清除。
