---
title: "Hugo部署 Github Actions"
summary: "Github Actions简介，并用其实现Hugo的部署。"
date: 2021-09-21T00:46:39+08:00
draft: true
cover:
    image: "https://images.liyangjie.cn/image/hugo-github-action-cover.png"
    alt: ""
categories: ["Hugo"]
tags: ["Hugo", "Github Actions", "rsync"]
katex: false
---
在[Hello Hugo](https://www.liyangjie.cn/posts/hellohugo/)文章中介绍了Hugo的入门，并使用git hook机制实现了一个简单的部署工作。在完善博客的过程中，我想实现读者的在线纠错、修改文章内容的功能，所以需要将文章内容托管到公有的平台，最好的选择当然是GitHub。这时候问题就来了，我关联了两个远程仓库，一个在自己的远程主机上，用于实现部署；另一个在GitHub上，方便读者进行在线编辑。每次在本地完成内容后，都要向两个远程仓库提交代码，这多少有些膈应，更重要的是，在线编辑的内容是要从GitHub上同步到我的远程主机的，显然这是不合适的。

