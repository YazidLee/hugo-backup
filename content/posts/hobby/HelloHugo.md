---
title: Hello Hugo
slug: hello-hugo
summary: Hugo 入门，以 PaperMod 主题为例进行基本配置，利用 Git 完成备份和部署工作。
author:
- SadBird
date: 2021-08-28T01:26:43.000+08:00
cover:
  image: https://d33wubrfki0l68.cloudfront.net/c38c7334cc3f23585738e40334284fddcaf03d5e/2e17c/images/hugo-logo-wide.svg
  alt: Hugo
categories:
- Hugo
tags:
- Hugo
katex: false

---
以前自己折腾过各种平台的博客，WordPress、Hexo、Jekyll  等，但最终都没有坚持把自己的博客搭建完成，不是这里效果不好，自己折腾不出来，然后一怒之下就弃了，要么就是工作出差，回来后就忘了，总之放弃是件简单的事情。

刚好处于工作真空期，想把一些平时学习的零碎内容整理一下，这次就坚持把这个博客完成了。这里就简单介绍下整个流程，及其中的一些坑和细节。篇幅较长，过程中可能有部分遗漏，轻喷。

首先是这次使用的博客平台，选择 [Hugo](https://gohugo.io/) 的理由很简单，因为没用过它，觉得新鲜，但实际上使用流程和搭建过程其实和以前接触过的静态站点生成框架大同小异。个人电脑环境是 Win10，以前安装过 `scoop`，因此安装方法如下：

```shell
scoop install hugo
# 检查hubo是否安装完成
hugo version
hugo v0.82.1-60618210 windows/amd64 BuildDate=2021-04-20T11:02:50Z VendorInfo=gohugoio
```

其他系统环境下安装方式见 [官网](https://gohugo.io/getting-started/installing/)。

***

## Hello Hugo

开始使用 Hugo 创建一个新站点 `hello-hugo`（这个名字各位自己决定，只要当前工作目录下不存在非空的重名子目录）:

```shell
hugo new site hello-hugo
```

执行成功后，Hugo 会给出温馨的提示：

{{< admonition type=tip title="hugo new site tip" open=true >}}
Just a few more steps and you're ready to go:

1. Download a theme into the same-named folder.<br/>
   Choose a theme from https://themes.gohugo.io/ or create your own with the "hugo new theme <THEMENAME>" command.
2. Perhaps you want to add some content. You can add single files with "hugo new <SECTIONNAME><FILENAME>.<FORMAT>".
3. Start the built-in live server via "hugo server".
   {{< /admonition >}}

等会我们就按这个顺序完成站点的创建。先看看执行完 `hugo new site` 命令后，Hugo 为我们做了什么。

### 工作目录内容

进入 `hello-hugo` 目录，Hugo 生成的内容如下图所示：

![](https://i.loli.net/2021/09/25/kINfz1TcXSOweRG.png)

这些大致作用如下：

* `archetypes`：存放博客的模板，默认提供了一个 `default.md` 作为所有博客的模板。
* `content`：顾名思义，存放我们所有的博客正文。
* `data`：存放一些数据，如 `xml`、`json` 等。
* `layouts`：与博客页面布局相关的内容，如博客网页中的 `header`、`footer` 等。
* `static`：存放静态资源，如图标、图片等。
* `themes`：主题相关。
* `config.toml`：站点、主题等相关内容的配置文件，它支持 `yaml`、`toml` 和 `json` 格式，后续将会一直和这个文件打交道。

除了上述几个目录之外，Hugo 还规定了许多其他目录用于提供不同的作用，如 `assets`、`i18n` 等。

### 主题下载和使用

根据提示，要使用 Hugo，我们必须先下载 [主题](https://themes.gohugo.io/) ~~（或自己创建主题）~~，这里我选择自己比较喜欢的 [PaperMod](https://themes.gohugo.io/themes/hugo-papermod/)。

先到 [PaperMod Giuhub](https://github.com/adityatelange/hugo-PaperMod)，根据官方文档的提示进行主题的下载。PaperMod 官方提供了 3 种下载方式，这里推荐第 2 种，以 `git submodule` 的方式下载。

进入 `hello-hugo` 目录，分别执行如下命令：

```bash
git init # 将hello-hugo初始化为git仓库
git submodule add https://github.com/adityatelange/hugo-PaperMod.git themes/PaperMod --depth=1 # 将PaperMod作为hello-hugo依赖的submodule
git submodule update --init --recursive # needed when you reclone your repo (submodules may not get cloned automatically)
# 使用这种方式，以后主题更新也比较方便
git submodule update --remote --merge 
```

完成后，会在 `themes` 目录下会多出一个 `PaperMod` 目录：

![](https://i.loli.net/2021/09/25/36qkXZ8UFBHuLb4.png)

可以发现，这个目录的结构与我们自己的 `hello-hugo` 目录十分相似，各目录的作用也基本一致。

随后，为了使用这个主题，需要在 `config.toml` 中激活，为了保持和 PaperMod 一致，这里将这个文件的后缀修改为 `.yml`，在 `config.yml` 中配置如下：

```yaml
baseURL: "https://example.org/"
languageCode: "en-us"
title: "Hello Hugo"
theme: "PaperMod"
```

这时候主题已经激活了，我们先往博客中添加一篇文章，首先创建名为 `posts` 的 `section`：

```shell
hugo new section posts
```

完成后，在 `content` 目录下创建了一个名为 `posts` 的目录，这就是我们存放文章的目录。随后创建一篇文章：

```shell
hugo new posts/HelloHugo1.md
hugo new posts/HelloHugo2.md
```

进入 `posts` 目录，编辑两个 `.md` 文件，写点内容：

```markdown
---
title: "HelloHugo1"
date: 2021-08-29T21:13:55+08:00
draft: false
---

# Hello, Hugo1
你好，雨果
```

```markdown
---
title: "HelloHugo2"
date: 2021-08-29T21:18:38+08:00
draft: false
---

# Hello, Hugo2
你好，雨果
```

文件头部为 Hugo 自动添加的内容，它来自 `archetypes` 目录中的 `default.md` 模板，注意 `draft` 属性，默认值为 `true` 表示文章处于草稿状态，该状态下的文档不会参与站点的生成，也就是说网站上没有草稿文章，所以此处需要将其先设置为 `false`。

现在可以使用 Hugo 内置的 Server 预览一下成果（工作目录必须在 `hugo-hello`）：

```shell
hugo server
```

![](https://i.loli.net/2021/09/25/Fi2SjNc3DB65sPf.png)

:sob: emmmmmmm，怎么说呢，有成果出来了，但是效果好像不太好，别急，接下来我们慢慢完善。

***

## 主题配置完善

基本上每个主题都会提供相应的 demo，PaperMod 的 [demo](https://adityatelange.github.io/hugo-PaperMod/) 如下：

![](https://i.loli.net/2021/09/25/SYBm6d2hvnpNPsl.png)

我们现在就以它为目标进行改进。

学习的最快方式就是模仿，所以我们直接到 [demo](https://adityatelange.github.io/hugo-PaperMod/) 的 github（注意是PaperMod demo 的 github，而不是 PaperMod 的 github）上把 `config.yml` 抄过来。

![](https://i.loli.net/2021/09/25/89J1xSA6d7kWutU.png)

可以注意到前几行配置我们就新增了一条 `paginate: 5`，其他保持不变，从 `enableInlineShortcodes` 开始都是来自 demo 的配置。

### languages, archives, search

在 demo 的 `languages` 的配置段中，有 `en`、`fr` 和 `fa` 3 块，它们使用的主题 Mode 不同，且包含部分国际化的配置，我们暂时只需要使用 `en`，可以将 `fr` 和 `fa` 注释或者直接删除掉。

`en` 下最重要的就是 `menu` 配置了，它表示了导航栏显示的内容，demo 中提供了最常用的 4 项，即 `Archive`、`Search`、`Tags` 及 `Categories`。每项中包含一个 `weight`，表示它们在导航栏中的显示顺序，越小越靠前。

根据 [PaperMod官方使用文档](https://github.com/adityatelange/hugo-PaperMod/wiki/Features) 的描述，要使用 `Archive` 和 `Search`，需要进行以下操作：

* 在 `content` 下增加 `archives.md` 文件，具体位置如下：

  ```shell
  .
  ├── config.yml
  ├── content/
  │   ├── archives.md   <--- Create archive.md here
  │   └── posts/
  ├── static/
  └── themes/
      └── PaperMod/
  ```

  `archives.md` 内容为：

  ```markdown
  ---
  title: "Archive"
  layout: "archives"
  url: "/archives/"
  summary: archives
  ---
  ```
* 在 `config.yml` 中新增如下内容，demo 中已经配置好的，这步可以跳过：

  ```yaml
  outputs:
      home:
          - HTML
          - RSS
          - JSON # is necessary
  ```

  同样在 `content` 新增一个 `search.md`，内容如下：

  ```markdown
  ---
  title: "Search" # in any language you want
  layout: "search" # is necessary
  # url: "/archive"
  # description: "Description for Search"
  summary: "search"
  ---
  ```

完成上述操作后，再看看效果：

![](https://i.loli.net/2021/09/25/gem9KWfEGqnp2sY.png)

:smirk: 像那么回事了吧！

### params

`params` 包括了 PaperMod 主题中的重要配置参数，下面举几个例子来进行说明，其他详细配置用法可以参照官方说明，也可以自己试试，大部分配置都是见名知意的。

#### 主题样式相关

* `defaultTheme`：设置白色主题或者黑色主题，设置为 `auto` 则表示跟随浏览器。
* `disableThemeToggle:`：是否允许白色主题和黑色主题进行手动切换，设置成 `true` 则在网页顶部提供切换按钮。
* `homeInfoParams`、`socialIcons`：这两参数配置的首页显示的内容，修改内容如下：

  ```yaml
  homeInfoParams:
          Title: "Hello Hugo"
          Content: >
              Lorem ipsum dolor sit amet, consectetuer adipiscing elit, 
              - sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat.
  socialIcons:
          - name: github
            url: "https://github.com/adityatelange/hugo-PaperMod"
          - name: telegram
            url: "https://ko-fi.com/adityatelange"
          - name: RsS
            url: "index.xml"
  ```

  结果如下：

![](https://i.loli.net/2021/09/25/xpYU7TqcIyGVR6Z.png)

关于 `socialIcons` 参数，[PaperMod官网](https://github.com/adityatelange/hugo-PaperMod/wiki/Icons) 给出了具体的参照表。

* 网站图标相关参数如下，可以指定网络路径或本地路径：

  ```yaml
  assets:
      favicon: "<link / abs url>"
      favicon16x16: "<link / abs url>"
      favicon32x32: "<link / abs url>"
      apple_touch_icon: "<link / abs url>"
      safari_pinned_tab: "<link / abs url>"
  ```

#### 博客内容相关

* `ShowShareButtons` 是否显示分享博客按钮，具体按钮的设定仍可参照 [PaperMod官网](https://github.com/adityatelange/hugo-PaperMod/wiki/Icons)。

  ![](https://i.loli.net/2021/09/25/LvTnSraM1fWI5zP.png)
* `ShowReadingTime` 是否显示文章阅读时间。
* `ShowBreadCrumbs` 是否显示面包屑。

  ![](https://i.loli.net/2021/09/25/BhbN3KgVlT2ZMyr.png)
* `ShowCodeCopyButtons` 是否显示代码复制按钮。
* `ShowToc` 是否显示文章目录。
* 博客封面相关：

  ```yaml
  cover:
      responsiveImages: false # 仅仅用在Page Bundle情况下，此处不讨论
      hidden: false # hide everywhere but not in structured data 是否在下面两种情况下显示
      hiddenInList: false # hide on list pages and home 是否在列表视图中显示
      hiddenInSingle: false # hide on single page 是否在单页视图中显示
  ```

  为了测试，我将后面 3 个配置项全部设置为 true，并在两篇测试博客中修改 front matter（就是博客最上方的数据）：

  ```markdown
  ---
  title: "HelloHugo1"
  date: 2021-08-29T21:13:55+08:00
  draft: 
  cover:
      image: "https://i.loli.net/2021/09/26/wBJrVXF9cefvtLZ.jpg"
      alt: "替换文本"
      caption: "封面标题"
  ---
  ```

  ```markdown
  ---
  title: "HelloHugo2"
  date: 2021-08-29T21:18:38+08:00
  draft: 
  cover:
      image: "https://i.loli.net/2021/09/26/pi3RYQSP12cJmWo.jpg"
      alt: "替换文本"
      caption: "封面标题"
  ---
  ```

  再来看看结果，是不是有点味道了：

  ![](https://i.loli.net/2021/09/25/r5o4qg8te1kYTVL.png)

  ![](https://i.loli.net/2021/09/25/rWwZmkPN83AYS6i.png)

### 分类相关

默认情况下，Hugo 支持 `categories`、`tags` 两个级别的分类，通过配置新增更多的分类：

```yaml
taxonomies:
    category: categories
    tag: tags
    series: series
```

这里又配置了一个 `series` 的分类维度，可以在博客的 front matter 中使用：

```markdown
---
title: "HelloHugo1"
date: 2021-08-29T21:13:55+08:00
draft: 
cover:
    image: "https://i.loli.net/2021/09/26/wBJrVXF9cefvtLZ.jpg"
    alt: "替换文本"
    caption: "封面标题"
categories:
    - Hugo
tags:
    - Hugo
series:
    - Hugo
---
```

这时候再进入网站的 `Tags` 导航项，就可以看到我们的标签和数量了：

![](https://i.loli.net/2021/09/25/yInRS3oc9KWQrBs.png)

### 代码样式相关

PaperMod 配置代码显示样式如下，这里是我个人使用的配置：

```yaml
markup:
    goldmark:
        renderer:
            unsafe: true
    highlight:
        # anchorLineNos: true
        codeFences: true
        guessSyntax: true
        lineNos: true
        # noClasses: false
        style: monokai
```

将 `lineNos` 设置为 true 后，会产生 bug，官方提供了解决方案：

在 `hugo-hello`，即工作目录下创建 `assets/css/custom.css` 文件，在文件中添加如下内容即可：

```css
.chroma {
    background-color: unset;
}
```

现在往第一篇博客中添加一个代码段如下：

````markdown
```java
public V put(K key, V value) {
    return putVal(hash(key), key, value, false, true);
}
```
````

显示效果如图：

![](https://i.loli.net/2021/09/25/wF3muHqsGAncCz6.png)

### 增加评论区

`Valine` 已经停止更新维护，因此将评论区功能换到了 `Twikoo`，[官方文档](https://twikoo.js.org/)非常详尽，各种方式的安装和配置都有，可直接前往查阅。

如果仍要使用 `Valine`，前置工作需要在 LeanCloud 上注册并创建应用，获取到相关的 `AppID` 和 `AppKey`，具体流程请参照  [Valine官方网站](https://valine.js.org/quickstart.html)。

获取到这两个参数后，根据 PaperMod 官方文档的指示，创建 `layouts/partials/comments.html` 文件，`partials` 路径不存在就自己创建，在文件中添加以下内容：

```html
{{ $valinejs := resources.Get "js/Valine.min.js" }}
<script src='{{ $valinejs.RelPermalink }}'></script>
<div id="vcomments"></div>
<script>
    new Valine({
      el: '#vcomments',
      appId: '这里是你的AppID',
      appKey: '这里是你的AppKey',
      placeholder: '来都来了，说两句~'
    })
</script>
```

随后创建 `assets/js/Valine.min.js`，将 [CDN](https://cdnjs.cloudflare.com/ajax/libs/valine/1.4.14/Valine.min.js) 中的内容全部拷贝到该文件中，保存。

在 `config.yml` 配置文件中设置评论开启即可，直接查找 `comments` 就可以定位到该配置的位置了，默认是关闭状态：

```yaml
comments: true
```

最后来看看效果：

![](https://i.loli.net/2021/09/25/Wkd3A7vbXstCG81.png)

配置入门大致就先讲到这里，下面简单介绍下我的站点部署方式。

***

## 部署相关

Hugo 与 Hexo 类似，提供了直接部署为 Github Pages 的方式，比较简单，请直接移步到 [官网](https://gohugo.io/hosting-and-deployment/hosting-on-github/)。

个人使用的最新部署方案已经单独在[另一篇博客](https://www.liyangjie.cn/posts/hobby/hugo-git-actions/)中进行详细介绍，以 GitHub 作为代码托管平台，使用 GitHub Action 完成部署。

如果打算将博客源码仓库放在自己的服务器上，还是可以采用下面的方案，同时也包含了 nginx 的简单配置。

### 准备工作

以前使用 Hexo 的时候在自己的云主机上进行了部署，当时域名整了好久（国内域名，需要备案），等域名搞定，黄花菜都凉了，所以这次刚好手头还保留着一台云主机，域名也一直在续费，就借此机会再折腾折腾。这个方案也是以前在别处看过的，具体出处已经找不到了，内容仅供参考。

#### 软件环境准备

* 云主机的操作系统为 `Debian 4.19.37-5+deb10u2 (2019-08-08) x86_64 GNU/Linux`，其他发行版也都可以。
* 静态资源服务器 `nginx/1.20.1`。
* `git/2.27.0`。

#### 域名、证书准备

* 准备好一个域名，并 DNS 解析至云服务器，国内需要走备案审批流程，国外域名则不需要，大家自行斟酌。
* 证书可选择各平台免费的 DV 证书，这里我随便找了一个腾讯云的 SSL 证书，品牌为 `TrustAsia`，有效期一年。

### git 仓库及钩子

准备充分后，先在服务器上新建一个名为 git 的用户专门用于 git 同步：

```shell
sudo adduser git
```

为了安全，修改分配给该用户的 shell 环境，编辑 `/etc/passwd` 文件，在末尾可以找到我们新增的 git 用户，修改后效果如下：

```shell
... ...
# 修改前为 git:x:1001:1001:,,,:/home/git:/bin/bash
git:x:1001:1001:,,,:/home/git:/usr/bin/git-shell
```

在自己的 **客户端(Win10)** 准备好 SSH 公钥，具体流程可以参照 [Github教程](https://docs.github.com/en/github/authenticating-to-github/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)。完成后，将公钥拷贝至服务器 `/home/git/.ssh/authorized_keys` 文件里，该文件中若有其他公钥，则在末尾换行后添加即可。

在适当目录创建 hugo 的裸仓库：

```shell
git init --bare hello-hugo.git
```

将该目录授权给刚创建好的 git 用户

```shell
sudo chown -R git:git hello-hugo.git
```

现在服务端的 git 仓库已经完成了，我们回到客户端。

进入 `hello-hugo` 目录，执行 git 初始化命令，将当前目录作为版本管理仓库：

```shell
git init
```

然后将当前目录及其子目录下的所有文件纳入版本管理，并提交到 git 本地仓库：

```shell
git add .
git commit -m "Hello, hugo"
```

将当前仓库关联到我们上面创建好的远程仓库，由于已经配置了 SSH 公钥，可以使用 SSH 协议：

```shell
git remote add origin ssh://git@your.domain:port/path/to/hello-hugo.git
git push --set-upstream origin master
```

远程仓库地址中的 `git` 为我们上面在服务器上创建的用户，`your.domai` 表示你自己的域名，`port` 为服务端的 SSH 端口，默认 22 可以不写，但是不为 22 的时候一定要使用如上的完整路径，此时 `ssh://` 不可省略。

我们已经完成了远程仓库和本地仓库的上下游关系关联。

为了方便每次提交文件后将静态目录自动部署到 nginx，选择用 git hook 在 `post-receive` 阶段将仓库中的 `/public` 整体移动到 nginx 指定路径。

再切回到服务端，进入 `hello-hugo.git` 目录，可以看到该目录下有个 `hooks` 目录，里面存放的就是 git 支持的所有钩子，git 官方在里面已经放了很多 `.sample` 结尾的示例，我们只选择使用 `post-receive` 钩子。创建 `post-receive` 文件，并使用 vim 进行修改，修改内容如下：

```shell
#!/bin/bash
git --work-tree=/usr/share/nginx/hello-hugo --git-dir=/path/to/hello-hugo.git checkout -f
```

其中 `--work-tree` 为 nginx 中要配置的静态资源路径，**请确保对于这个路径，我们上面创建的 git 用户需要有写入权限**，具体命令参照上面的 `hello-hugo.git` 配置；`--git-dir` 就是服务端的 `hello-hugo.git` 仓库路径。

在 **客户端** 我们新建一篇名为 `HelloHugo3.md` 的博客，记得把 `draft` 设置为 false，然后往里面加点内容。同样在 **客户端** 进入 `hello-hugo` 目录，执行 `hugo` 命令，该命令的作用是将所有的资源生成为静态站点，并将站点存放在 `hello-hugo` 的 `public` 目录下：

```shell
hugo # 生成站点
```

再执行 git 操作：

```shell
git add .
git commit -m "publish site"
git push # 这个客户端操作将会触发服务端执行post-receive脚本
```

一切正常的话，服务端的 `/usr/share/nginx/hello-hugo` 目录下将会和我们的客户端工作目录一致（空目录和 `submodule` 不会被 git 纳入版本控制，因此 `data`、`static`、`themes` 目录不会同步到服务器）。

### nginx 配置

上传 SSL 证书至 `/etc/nginx/cert` 目录下，nginx 使用的格式为：

* `your.domain_bundle.crt`
* `your.domain.key`

进入 nginx 配置目录 `/etc/nginx/conf.d`，新建 `hello-hugo.conf` 文件，内容如下，端口号和路径可以根据实际情况进行修改，保证没有被占用：

```nginx
server {
    listen 443 ssl; # https端口号，默认为443，可以自己修改
    server_name your.domain; # 域名，与申请证书时候使用的域名要一致

    # https相关配置
    ssl_certificate  cert/your.domain_bundle.crt;
    ssl_certificate_key cert/your.domain.key; 
    ssl_session_timeout 5m;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;

    # 这个路径就是上面我们的git hook指定的路径，再接上一个public
    root /usr/share/nginx/hello-hugo/public;

    # 默认查找路径下的index.html
    location / {
        index index.html index.htm;
    }

    # 默认的404页面
    error_page 404 /404.html; 
        location = /40x.html {
    }
}

server {
    listen 80; # 端口号可以自己修改
    server_name your.domain; # 域名，与申请证书时候使用的域名要一致

    # 将http重定向到https，host后面的端口号与上一个server的端口号保持一致即可
    return 301 https://$host:443$request_uri;  
}
```

最后，开启 nginx：

```shell
nginx
```

客户端打开浏览器，输入你的域名（默认 80 端口可以不写，否则必须写），能够成功跳转到 `https` ，地址栏能够显示小锁（小锁表示网站使用的证书是安全的）就表示已经成功了：

![](https://i.loli.net/2021/09/25/vu12beN6YnJIdV5.png)

## 留个坑

至此，Hugo 从入门部署已经完成了，关于 Hugo 的使用细节没有覆盖到，主要是我自己也才刚开始使用，后续会慢慢积累和整理，争取把记录生活的习惯坚持下去，共勉 :sunglasses:。