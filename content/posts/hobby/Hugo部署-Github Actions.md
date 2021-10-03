---
title: Hugo 部署——Github Actions
slug: hugo-git-actions
summary: Github Actions 简介，并用其实现 Hugo 的部署。
author:
- SadBird
date: 2021-09-21T00:46:39.000+08:00
cover:
  image: https://i.loli.net/2021/09/24/COFQ9BImX2ajTVU.png
  alt: ''
categories:
- Hugo
tags:
- Hugo
- Github Actions
- rsync
katex: false

---
在 [Hello Hugo](https://www.liyangjie.cn/posts/hobby/hello-hugo/) 文章中介绍了 Hugo 的入门，并使用 git hook 机制实现了一个简单的部署工作。在完善博客的过程中，我想实现读者在线纠错、修改文章内容的功能，需要将文章内容托管到公有的平台，最好的选择当然是 GitHub。这时候问题就来了，我关联了两个远程仓库，一个在自己的远程主机上，用于实现部署；另一个在 GitHub 上，方便读者进行在线编辑。每次在本地完成内容后，都要向两个远程仓库提交代码，这多少有些膈应，更重要的是，在线编辑的内容是要从 GitHub 上同步到我的远程主机的，显然这是不合适的。

Hugo官方提供了多种部署方式，其中，[Host on GitHub](https://gohugo.io/hosting-and-deployment/hosting-on-github/) 和 [Deployment with Rsync](https://gohugo.io/hosting-and-deployment/deployment-with-rsync/) 结合正好可以满足我的需求，具体实现是直接放弃自己远程主机上的仓库，并使用 GitHub Actions 进行站点的部署。

***

## GitHub Actions

### 概念

官方文档给出的定义如下：
{{< admonition type=quote title="GitHub Actions" open=true >}}
Automate, customize, and execute your software development workflows right in your repository with GitHub Actions. You can discover, create, and share actions to perform any job you'd like, including CI/CD, and combine actions in a completely customized workflow.
{{< /admonition >}}

GitHub Actions 是 GitHub 官方提供的一种自动化、定制化的工作流，包括了 CI/CD。关于 CI/CD 的简单理解：

* CI：持续集成（_Continuous Integration_），使用 Git 向代码仓库推送代码后，后台将会自动进行构建、测试等工作。
* CD：持续交付（_Continuous Delivery_），推送完成的代码（经过了自动构建、测试等流程），最终部署到生产服务器，供客户直接使用。

GitHub Actions 中的几个重要概念如下：

* `workflow`：工作流，持续集成一次运行的过程，就是一个 `workflow` 。
* `enent`：事件，表示触发 `workflow` 执行的某些特定活动，例如某些 `workflow` 可以在仓库中的 `push`、`pull request` 发生时开始执行。
* `job`：任务，每个 `workflow` 都可以包含一个或多个 `job`，表示每次持续集成可以执行多个任务。
* `step`：步骤，每个 `job` 可以包含一个或多个 `step`，表示每个任务可以由多个步骤完成。
* `action`：动作命令，每个 `step` 包含多个 `action`，它是 `workflow` 的最小单元，通常是独立的脚本命令。
* `runner`：执行 `workflow` 的服务器，可以使用 GitHub 内置的服务器，也可以使用自己的服务器。使用自定义的服务器时，需要在服务器上安装 [GitHub Actions Runner](https://github.com/actions/runner)。

下图由 [GitHub官方](https://docs.github.com/en/actions/learn-github-actions/understanding-github-actions) 提供，表示 GitHub Actions 的整体结构：

![](https://i.loli.net/2021/09/24/Lu1MjwvToWkdxC9.png)

### 简单示例

GitHub Actions 的具体实现是在当前工作目录下创建 `.github/workflows/`，并在目录中添加 `.yml` 脚本文件，每个 `.yml` 文件都代表了一个 `workflow`。目录结构如下：

```
- .github
  |- workflows
    |- workflow1.yml
    |- workflow2.yml
```

下面是 [GitHub官方](https://docs.github.com/en/actions/learn-github-actions/understanding-github-actions) 提供的示例文件：


```yaml
name: learn-github-actions
on: [push]
jobs:
  check-bats-version:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-node@v2
        with:
          node-version: '14'
      - run: npm install -g bats
      - run: bats -v
```

| 代码 | 说明 |
| :--- | :--- |
| name: learn-github-actions | 可选，表示 workflow 的名称，可以在 GitHub Actions 的标签中显示 |
| on: \[push\] | 表示触发 workflow 的事件，这里的 push 表明每次进行 push 时都会执行当前的 workflow |
| jobs: | 表示开始定义 workflow 的具体任务 |
| check-bats-version: | 自定义的第一个 job 名称 |
| runs-on: ubuntu-latest | 表示使用GitHub提供的 runner ，系统环境为 ubuntu-latest |
| steps: | 开始定义 check-bats-version 任务的具体 step |
| - uses: actions/checkout@v2 | uses 表示使用在 GitHub 社区中提供的名为 actions/checkout@v2 的 workflow ，它的工作是将仓库中的代码检出并下载到 runner 中，它通常是一个 step 的起点 |
| - uses: actions/setup-node@v2 | 表示使用 actions/setup-node@v2 的 workflow ，它的工作是在当前 runner　中安装 node 环境，该环境提供了 npm 命令， with 表示传入该 workflow 的参数，由该 workflow 内部使用，这里指定了 node 的版本号 |
| - run: npm install -g bats | run 表示在 runner 中执行具体的命令，这里使用 npm install -g bats 进行全局安装 |
| - run: bats -v | 执行 bats -v 命令，打印 bats 的版本 |

该 action 的执行流程如下图所示：

![](https://i.loli.net/2021/09/24/MflcjixQ5VWZwSa.png)

为了使 GitHub Actions 能得到复用，GitHub 提供了发布的机制，可以将自己写好的 action 分享给其他用户使用，详细步骤可以参考 [官方文档](https://docs.github.com/en/actions/creating-actions/publishing-actions-in-github-marketplace)。
上面示例所示，`actions/setup-node` 就是一个在社区中分享的action，它表示 github.com/actions/setup-node 这个仓库，同时也是一个 action，作用是安装 `Node.js`，而 `v2` 就表示了使用的 `actions/setup-node` 的版本为 `v2` 。

{{< admonition type=tip title="GitHub Actions费用相关" open=true >}}

* 所有的公有仓库免费。
* 用户使用自己提供的 `runner` 也是免费。
* 私有仓库，且使用的是 GitHub 提供的 `runner`，收费标准见 [官网](https://docs.github.com/en/billing/managing-billing-for-github-actions/about-billing-for-github-actions)。
  {{< /admonition >}}

***

## Hugo 部署

### 准备工作

* 远程主机配置

  部署流程使用 `rsync` 进行文件的同步工作， `rsync` 默认是基于 SSH，需要提前在自己的远程主机上安装 `rsync`，并准备密钥对。

  这里使用 [上篇文章](https://www.liyangjie.cn/posts/hobby/hello-hugo/) 中创建的 git 用户作为同步数据时使用的账户：

  ```shell
  # 安装 rsync
  sudo apt-get install rsync
  
  cd /home/git
  
  mkdir .ssh
  
  cd .ssh
  
  # 不支持Ed25519算法的系统请使用 ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
  ssh-keygen -t ed25519 -C "your_email@example.com"
  
  # 交互完成密钥的生成
  Generating public/private ed25519 key pair.
  Enter file in which to save the key (/root/.ssh/id_ed25519): rsync # 输入密钥对名称，默认名id_ed25519
  Enter passphrase (empty for no passphrase):  # 输入密码，这里选择不输入
  Enter same passphrase again:  # 重复上述密码
  
  # 成功
  Your identification has been saved in rsync.
  Your public key has been saved in rsync.pub.
  The key fingerprint is:
  SHA256:xxxxxxxxxxxx/xxx/xxxxxxxxxxx/xxx your_email@example.com
  The key's randomart image is:
  +--[ED25519 256]--+
  |                 |
  |     o +   .o o +|
  |                .|
  |    + .   oo    .|
  |                 |
  |                 |
  |  + .o+     o oo.|
  |   o. ..     +  +|
  |                 |
  +----[SHA256]-----+
  ```

  密钥对生成成功后，在 `.ssh` 目录下新建 `authorized_keys` 文件，并将公钥信息增加到该文件末尾：

  ```shell
  cat rsync.pub >> authorized_keys 
  ```

  私钥文件中的内容需要拷贝到 GitHub，稍后介绍。
* GitHub Secrets 配置

  Secrets 是提供给 action 使用的安全变量机制，Secrets 中定义的变量都会进行加密，但后续可以在 action 中正常使用。

  进入 Hugo 博客仓库，点击 `Settings`，左侧找到 `Secrets`，进入 Secrets 配置:

  ![](https://i.loli.net/2021/09/24/zoHPdwagGpcxWO7.png)

  如图所示，点击右上角的 `New repository secret` 创建新变量：这里先创建私钥变量 `REMOTE_KEY`，在变量 `Name` 中输入 `REMOTE_KEY`。从服务器上拷贝私钥文件 `rsync` 的全部内容到 `Value` 中，点击 `Add secret` 保存：

  ```shell
  cat rsync
  # 拷贝输出中所有内容
  -----BEGIN OPENSSH PRIVATE KEY-----
  ...
  -----END OPENSSH PRIVATE KEY-----
  ```

  ![](https://i.loli.net/2021/09/24/Omepn6wQSu8RK7U.png)

  使用同样的方式创建剩余 Secrets：
  * `REMOTE_HOST`：远程主机地址。
  * `REMOTE_PORT`：远程主机 SSH 端口，默认为 22 可不配置，若不是 22 必须配置。
  * `REMOTE_USER`：数据同步使用的用户，如本文中使用的 git。
  * `REMOTE_PATH`：远程主机上的目标路径，同步文件将会拷贝到该路径中，如 nginx 配置的静态网站路径。

### 配置 GitHub Actions

在仓库目录下创建 `.github/workflows` 目录，并且在目录中创建 `deploy.yml` 文件：

```
- .github
  |- workflows
    |- deploy.yml
```

`deploy.yml` 中的内容如下：

```yaml
name: deploy

on:
  # push事件
  push:
    # 忽略某些文件和目录，自行定义
    paths-ignore:
      - '.forestry/**'
      - 'archetypes/**'
      - '.gitignore'
      - '.gitmodules'
      - 'README.md'
    branches: [ master ]

  # pull_request事件
  pull_request:
    # 忽略某些文件和目录，自行定义
    paths-ignore:
      - '.forestry/**'
      - 'archetypes/**'
      - '.gitignore'
      - '.gitmodules'
      - 'README.md'
    branches: [ master ]
  
  # 支持手动运行
  workflow_dispatch:
    
jobs:
  # job名称为deploy
  deploy:
    # 使用GitHub提供的runner
    runs-on: ubuntu-20.04

    steps:
      # 检出代码，包括submodules，保证主题文件正常
      - name: Checkout source
        uses: actions/checkout@v2
        with:
          ref: master
          submodules: true  # Fetch Hugo themes (true OR recursive)
          fetch-depth: 0    # Fetch all history for .GitInfo and .Lastmod
      
      # 准备Hugo环境
      - name: Setup Hugo
        uses: peaceiris/actions-hugo@v2
        with:
          hugo-version: 'latest'
          # extended: true

      # Hugo构建静态站点，默认输出到public目录下    
      - name: Build
        run: hugo --gc --verbose --minify

      # 将public目录下的所有内容同步到远程服务器的nginx站点路径，注意path参数的写法，'public'和'public/'是不同的
      - name: Deploy
        uses: burnett01/rsync-deployments@5.1
        with:
          switches: -avzr --delete
          path: ./public/
          remote_host: ${{ secrets.REMOTE_HOST }}
          remote_port: ${{ secrets.REMOTE_PORT }}
          remote_path: ${{ secrets.REMOTE_PATH }}
          remote_user: ${{ secrets.REMOTE_USER }}
          remote_key: ${{ secrets.REMOTE_KEY }}
```

action 的 3 个 `step` 工作内容分别如下：

1. 先检出代码到 `runner`，包括 submodule 下的内容，这是为了保证作为 submodule 的主题目录能正常使用。
2. [`actions-hugo@v2`](https://github.com/marketplace/actions/hugo-setup#%EF%B8%8F-create-your-workflow) 安装准备好 Hugo 的环境，`with` 表示 Hugo 版本为 latest。
3. `hugo --gc --verbose --minify` 构建 Hugo 静态站点，默认输出到 public 目录中。
4. [`rsync-deployments@5.1`](https://github.com/marketplace/actions/rsync-deployments-action) 将 public 目录中 **所有的内容** 全部拷贝到服务器指定路径，这里 `${{ secrets.XXX }}` 引用我们之前创建好的 Secrets 变量。注意在使用 `rsync` 时 public 与 public/ 的区别。前者会在目标目录中创建同名目录 public，后者不会创建该目录，而是直接将源目录public中的 **所有内容** 拷贝到目标目录。要了解更多关于 `rsync` 的使用细节可以参考 [这篇文章](https://www.ruanyifeng.com/blog/2020/08/rsync.html)。

### 检验结果

将新创建好的 action push 到 GitHub 仓库，在 Actions 标签下就可以看到所有的 action 了。

![](https://i.loli.net/2021/09/24/6ErZavgHNf3hFXM.png)

本地修改一些代码，提交并 push 后，可以看到 `deploy` 这个 action 的执行过程，包括执行结果（成功或者失败）、执行时间、输出等信息。

![](https://i.loli.net/2021/09/24/UdNvXwi9aHCYItS.png)

访问自己的站点，看看是否运行成功。若一切正常，这次的部署转移计划算是顺利完成了。