---
title: "Lua 脚本入门"
slug: "hello-lua"
summary: "东拼西凑之 Lua"
author: ["SadBird"]
date: 2022-02-05T22:08:07+08:00
cover:
    image: "https://s2.loli.net/2022/02/05/qse7aYBtTA9xcju.png"
    alt: ""
categories: ["lua"]
tags: ["lua"]
katex: false
mermaid: false
draft: true
---

## 瞎折腾

在老笔记本上装上了 Manjaro，想整个 NeoVim 体验体验。NeoVim 内部集成了 Lua，许多插件及其配置都离不开 Lua，而且在 Redis 中也是使用 Lua 作为默认的脚本语言，到处都能看到它的身影，花点时间入个门还是挺合算的。

## Hello, world

第一个程序肯定是从 Hello World 开始了，但是首先要有 Lua 的执行环境。我还是在 Windows11 上进行学习，因此直接在[官网](http://luabinaries.sourceforge.net/)下载了二进制可执行文件，配置好环境变量就能直接用了，很简单。

```lua
print('Hello, world!')
```

使用 `lua hello.lua` 就可以直接执行，在控制台输出结果。

