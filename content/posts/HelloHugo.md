---
title: "Hello Hugo"
date: 2021-08-28T01:26:43+08:00
draft: false
cover:
    image: "https://d33wubrfki0l68.cloudfront.net/c38c7334cc3f23585738e40334284fddcaf03d5e/2e17c/images/hugo-logo-wide.svg"
    alt: "Hugo"
categories:
    - Hugo
tags:
    - Hugo
---

以前自己折腾过各种平台的博客，WordPress、Hexo、Jekyll等，但最终都没有坚持把自己的博客搭建完成，不是这里效果不好，自己折腾不出来，然后一怒之下就弃了，要么就是工作出差，回来后就忘了，总之放弃是件简单的事情。

刚好处于工作真空期，想把一些平时学习的零碎内容整理一下，这次就坚持把这个博客完成了。这里就简单介绍下整个流程，及其中的一些坑和细节。

首先是这次使用的博客平台，选择[Hugo](https://gohugo.io/)的理由很简单，因为没用过它，觉得新鲜，但实际上使用流程和搭建过程其实和以前接触过的静态站点生成框架大同小异。个人电脑环境是Win10，以前安装过`scoop`，因此安装方法如下：

```shell
scoop install hugo
# 检查hubo是否安装完成
hugo version
hugo v0.82.1-60618210 windows/amd64 BuildDate=2021-04-20T11:02:50Z VendorInfo=gohugoio
```

其他系统环境下安装方式见[官网](https://gohugo.io/getting-started/installing/)。

# Hello Hugo

开始使用Hugo创建一个新站点`hello-hugo` (这个名字各位自己决定，只要当前工作目录下不存在非空的重名子目录):

```shell
hugo new site hello-hugo
```

执行成功后，Hugo会给出温馨的提示：

> Just a few more steps and you're ready to go:
>
> 1. Download a theme into the same-named folder.<br/>
>    Choose a theme from https://themes.gohugo.io/ or create your own with the "hugo new theme <THEMENAME>" command.
> 2. Perhaps you want to add some content. You can add single files with "hugo new <SECTIONNAME>\<FILENAME>.<FORMAT>".
> 3. Start the built-in live server via "hugo server".

等会我们就按这个顺序完成站点的创建。先看看执行完`hugo new site`命令后，Hugo为我们做了什么。

## 工作目录内容

进入`hello-hugo`目录，Hugo生成的内容如下图所示：

![](http://images.liyangjie.cn/image/Hugo_init_directory.png#center)

这些大致作用如下：

- `archetypes`：存放博客的模板，默认提供了一个`default.md`作为所有博客的模板
- `content`：顾名思义，存放我们所有的博客正文
- `data`：存放一些数据，如`xml`、`json`等
- `layouts`：与博客页面布局相关的内容，如博客网页中的`header`、`footer`等
- `static`：存放静态资源，如图标、图片等
- `themes`：主题相关
- `config.toml`：站点、主题等相关内容的配置文件，它支持`yaml`、`toml`和`json`格式，后续将会一直和这个文件打交道

除了上述几个目录之外，Hugo还规定了许多其他目录用于提供不同的作用，如`assets`、`i18n`等。

## 主题下载和使用

根据提示，要使用Hugo，我们必须先下载[主题](https://themes.gohugo.io/)~~(或自己创建主题)~~，这里我选择自己比较喜欢的[PaperMod](https://themes.gohugo.io/themes/hugo-papermod/)。

先到[PaperMod Giuhub](https://github.com/adityatelange/hugo-PaperMod)，根据官方文档的提示进行主题的下载。PaperMod官方提供了3种下载方式，这里推荐第二种，以`git submodule`的方式下载。

进入`hello-hugo`目录，分别执行如下命令：

```bash
git init # 将hello-hugo初始化为git仓库
git submodule add https://github.com/adityatelange/hugo-PaperMod.git themes/PaperMod --depth=1 # 将PaperMod作为hello-hugo依赖的submodule
git submodule update --init --recursive # needed when you reclone your repo (submodules may not get cloned automatically)
```

完成后，会在`themes`目录下会多出一个`PaperMod`目录：

![](http://images.liyangjie.cn/image/Hugo_theme_directory.png#center)

可以发现，这个目录的结构与我们自己的`hello-hugo`目录十分相似，各目录的作用也基本一致。

随后，为了使用这个主题，需要在`config.toml`中激活，为了保持和PaperMod一致，这里将这个文件的后缀修改为`.yml`，在`config.yml`中配置如下：

```yaml
baseURL: "http://example.org/"
languageCode: "en-us"
title: "Hello Hugo"
theme: "PaperMod"
```

这时候主题已经激活了，我们先往博客中添加一篇文章，首先创建名为`posts`的`section`：

```shell
hugo new section posts
```

完成后，在`content`目录下创建了一个名为`posts`的目录，这就是我们存放文章的目录。随后创建一篇文章：

```shell
hugo new posts/HelloHugo1.md
hugo new posts/HelloHugo2.md
```

进入`posts`目录，编辑两个`.md`文件，写点内容：

```markd
---
title: "HelloHugo1"
date: 2021-08-29T21:13:55+08:00
draft: false
---

# Hello, Hugo1
你好，雨果
```

```markd
---
title: "HelloHugo2"
date: 2021-08-29T21:18:38+08:00
draft: false
---

# Hello, Hugo2
你好，雨果
```

文件头部为Hugo自动添加的内容，它来自`archetypes`目录中的`default.md`模板，注意`draft`属性，默认值为`true`表示文章处于草稿状态，该状态下的文档不会参与站点的生成，也就是说网站上没有草稿文章，所以此处需要将其先设置为`false`。

现在可以使用Hugo内置的Server预览一下成果(工作目录必须在`hugo-hello`)：

```shell
hugo server
```

![](http://images.liyangjie.cn/image/Hugo_PaperMod_init.png#center)

:sob:emmmmmmm，怎么说呢，有成果出来了，但是效果好像不太好，别急，接下来我们慢慢完善。

# 主题配置完善

基本上每个主题都会提供相应的demo，PaperMod的[demo](https://adityatelange.github.io/hugo-PaperMod/)如下：

![](http://images.liyangjie.cn/image/Hugo_PaperMod_demo.png#center)

我们现在就以它为目标进行改进。

学习的最快方式就是模仿，所以我们直接到[demo](https://adityatelange.github.io/hugo-PaperMod/)的github(注意是PaperMod demo的github，而不是PaperMod的github)上把`config.yml`抄过来。

![](http://images.liyangjie.cn/image/Hugo_PaperMod_demo_config.png#center)

可以注意到前几行配置我们就新增了一条`paginate: 5`，其他保持不变，从`enableInlineShortcodes`开始都是来自demo的配置。

## languages、archives、search

在demo的`languages`的配置段中，有`en`、`fr`和`fa`3块，它们使用的主题Mode不同，且包含部分国际化的配置，我们暂时只需要使用`en`，可以将`fr`和`fa`注释或者直接删除掉。

`en`下最重要的就是`menu`配置了，它表示了导航栏显示的内容，demo中提供了最常用的4项，即`Archive`、`Search`、`Tags`及`Categories`。每项中包含一个`weight`，表示它们在导航栏中的显示顺序，越小越靠前。

根据[PaperMod官方使用文档](https://github.com/adityatelange/hugo-PaperMod/wiki/Features)的描述，要使用`Archive`和`Search`，需要进行以下操作：

- 在`content`下增加`archives.md`文件，具体位置如下：

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

  `archives.md`内容为：

  ```mark
  ---
  title: "Archive"
  layout: "archives"
  url: "/archives/"
  summary: archives
  ---
  ```
- 在`config.yml`中新增如下内容，demo中已经配置好的，这步可以跳过：
  ```yaml
  outputs:
      home:
          - HTML
          - RSS
          - JSON # is necessary
  ```
  同样在`content`新增一个`search.md`，内容如下：
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

![](http://images.liyangjie.cn/image/Hugo_PaperMod_archives+search.png#center)

:smirk:像那么回事了吧！

## params

`params`包括了PaperMod主题中的重要配置参数，下面举几个例子来进行说明，其他详细配置用法可以参照官方说明，也可以自己试试，大部分配置都是见名知意的。

### 主题样式相关

- `defaultTheme`：设置白色主题或者黑色主题，设置为`auto`则表示跟随浏览器

- `disableThemeToggle:`：是否允许白色主题和黑色主题进行手动切换，设置成`true`则在网页顶部提供切换按钮

- `homeInfoParams`、`socialIcons`：这两参数配置的首页显示的内容，修改内容如下：

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

  ![](http://images.liyangjie.cn/image/Hugo_PaperMod_home_info.png#center)
  
  关于`socialIcons`参数，[PaperMod官网](https://github.com/adityatelange/hugo-PaperMod/wiki/Icons)给出了具体的参照表。
  
- 网站图标相关参数如下，可以指定网络路径或本地路径：

  ```yaml
  assets:
      favicon: "<link / abs url>"
      favicon16x16: "<link / abs url>"
      favicon32x32: "<link / abs url>"
      apple_touch_icon: "<link / abs url>"
      safari_pinned_tab: "<link / abs url>"
  ```

### 博客内容相关

- `ShowShareButtons`是否显示分享博客按钮，具体按钮的设定仍可参照[PaperMod官网](https://github.com/adityatelange/hugo-PaperMod/wiki/Icons)

  ![](http://images.liyangjie.cn/image/Hugo_shareicons.png#center)

- `ShowReadingTime`是否显示文章阅读时间

- `ShowBreadCrumbs` 是否显示面包屑

  ![](http://images.liyangjie.cn/image/Hugo_breadcrumbs.png#center)

- `ShowCodeCopyButtons`是否显示代码复制按钮

- `ShowToc`是否显示文章目录

- 博客封面相关：

  ```yaml
  cover:
      responsiveImages: false # 仅仅用在Page Bundle情况下，此处不讨论
      hidden: false # hide everywhere but not in structured data 是否在下面两种情况下显示
      hiddenInList: false # hide on list pages and home 是否在列表视图中显示
      hiddenInSingle: false # hide on single page 是否在单页视图中显示
  ```

  为了测试，我将后面3个配置项全部设置为true，并在两篇测试博客中修改front matter(就是博客最上方的数据):

  ```markdown
  ---
  title: "HelloHugo1"
  date: 2021-08-29T21:13:55+08:00
  draft: 
  cover:
      image: "https://images.liyangjie.cn/Sekiro_01.jpg"
      alt: "替换文本"
      caption: "封面标题"
  ---
  ```

  ```mark
  ---
  title: "HelloHugo2"
  date: 2021-08-29T21:18:38+08:00
  draft: 
  cover:
      image: "https://images.liyangjie.cn/Sekiro_02.jpg"
      alt: "替换文本"
      caption: "封面标题"
  ---
  ```

  再来看看结果，是不是有点味道了：

  ![](http://images.liyangjie.cn/image/Hugo_list_with_cover.png#center)

  
  
  ![](http://images.liyangjie.cn/image/Hugo_single_with_cover.png#center)
  
  

## 分类相关

默认情况下，Hugo支持`categories`、`tags`两个级别的分类，通过配置新增更多的分类：

```yaml
taxonomies:
    category: categories
    tag: tags
    series: series
```

这里又配置了一个`series`的分类维度，可以在博客的front matter中使用：

```mark
---
title: "HelloHugo1"
date: 2021-08-29T21:13:55+08:00
draft: 
cover:
    image: "https://images.liyangjie.cn/Sekiro_01.jpg"
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

这时候再进入网站的`Tags`导航项，就可以看到我们的标签和数量了：

![](http://images.liyangjie.cn/image/Hugo_tags.png#center)

## 代码样式相关

PaperMod0配置代码显示样式如下，这里是我个人使用的配置：

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

将`lineNos`设置为true后，会产生bug，官方提供了解决方案：

在`hugo-hello`，即工作目录下创建`assets/css/custom.css`文件，在文件中添加如下内容即可：

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

![](http://images.liyangjie.cn/image/Hugo_code.png#center)

## 增加评论区

我选择使用的是`Valine`，前置工作需要在LeanCloud上注册并创建应用，获取到相关的`AppID`和`AppKey`，具体流程请参照[Valine官方网站](https://valine.js.org/quickstart.html)。

获取到这两个参数后，根据PaperMod官方文档的指示，创建`layouts/partials/comments.html`文件，`partials`路径不存在就自己创建，在文件中添加以下内容：

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

随后创建`assets/js/Valine.min.js`，将[CDN](https://cdnjs.cloudflare.com/ajax/libs/valine/1.4.14/Valine.min.js)中的内容全部拷贝到该文件中，保存。

在`config.yml`配置文件中设置评论开启即可，直接查找`comments`就可以定位到该配置的位置了，默认是关闭状态：

```yaml
comments: true
```

最后来看看效果：

![](http://images.liyangjie.cn/image/Hugo_comments.png#center)

配置入门大致就先讲到这里，下面简单介绍下我的站点部署方式。

# 部署相关

[TODO]

