---
title: "Windows 激活——MAS"
slug: "windows-activation"
summary: "Windows MAS（Microsoft Activation Scripts）激活脚本介绍及使用，支持 Win10、11。"
author: ["SadBird"]
date: 2021-10-23T16:41:53+08:00
cover:
    image: "https://i.loli.net/2021/10/24/cHZTUwjKkP2xbJq.png"
    alt: ""
categories: ["Windows Tool"]
tags: ["Windows 激活"]
katex: false

---
## MAS

时至今日，仍然有很多朋友对 Windows 的激活束手无策，百度搜索出来的解决方案也是五花八门，甚至有些是恶意病毒，这更让「白嫖」的小白用户痛不欲生。

为了解决激活问题，本文推荐一个安全、便捷的 Windows 激活脚本开源项目：[Microsoft Activation Scripts](https://windowsaddict.ml/)。

{{< admonition type=quote title="Microsoft Activation Scripts" open=true >}}

A collection of scripts for activating Microsoft products using HWID / KMS38 / Online KMS activation methods with a focus on open-source code, less antivirus detection and user-friendliness.

{{< /admonition >}}

简单来说，*Microsoft Activation Scripts* 是一款安全开源的 Windows 产品激活工具，提供了多种激活方法和友好的用户交互界面。

---

## 下载使用

官方提供了 [GitHub](https://github.com/massgravel/Microsoft-Activation-Scripts/releases) 和 [GitLab](https://gitlab.com/massgrave/microsoft-activation-scripts/-/releases) 两个下载地址，请自行选择。此处以 GitHUB 为例进行介绍：

![](https://s2.loli.net/2022/01/26/fkRKWxLzOtmucZi.png)

下载后，使用图中所示解压密码进行解压，得到 `MAS_1.5` 目录。目录结构如下：

```shell
MAS_1.5
├─ All-In-One-Version
└─ Separate-Files-Version
```

其中，`All-In-One-Version` 目录中为集成脚本，提供了所有激活方法的快捷操作入口。而 `Separate-Files-Version` 为具体的各个激活方法的独立脚本，用户可以根据需要自行选择执行。剩余 `ReadMe.html` 为说明文档，`Verify_Files-Clear_Zone.Identifier-68.cmd` 校验文件并对时区进行清理，防止 SmartScreen 警告。

作为小白用户，这里当然推荐直接使用集成脚本，进入 `All-In-One-Version` 目录，直接双击执行该目录下的执行脚本（这里 1.5 版本为 `MAS_1.5_AIO_CRC32_21D20776.cmd`），界面如下：

![](https://s2.loli.net/2022/01/26/9mnQ8btSqkldiZM.png)

根据提示的选项，输入具体的数字进行进行激活即可：

- `1`：HWID 激活（永久，支持 Win 10-11）。
- `2`：KMS38 激活（有效期至 2038年，适用于 Win10-11-Server）。
- `3`：Online KMS 激活（有效期 180 天，支持 Win7 以上和 Office）。
- `4`：查看当前激活状态（vbs）。
- `5`：查看当前激活状态（wmi）。
- `6`：其他功能选项（如预激活镜像制作等）。
- `7`：说明文档，详细介绍了每种激活方法支持的 Windows 产品，使用方法等。
- `8`：退出。

当然，最重要的就是其中的 `1-3` 这三个选项了，分别使用 3 种不同的方式进行激活。对于 Win10、11，这里推荐使用 `1：HWID` 进行激活，而对于 Win7 只能选择 `3：Online KMS` 进行激活，`3：Online KMS` 同样支持 Office 的激活，但不推荐使用。对于 Office 这里推荐一个从安装到激活的 Office 一站式部署工具 [Office Tool Plus](https://otp.landian.vip/)。

这里以 `1: HWID` 为例进行演示：
- 首先在主界面输入 `1`，即可进入 `HWID` 激活界面：
  ![](https://s2.loli.net/2022/01/26/zju2QlJGIi3kKZ6.png)
- 在上述界面中，再次输入 `1`，开始进行 Windows 激活，完成后，如下图所示：
  ![](https://s2.loli.net/2022/01/26/ByHvRPmzl2NJE9e.png)

激活成功后，使用如下命令查看激活状态：

```shell
slmgr.vbs -xpr
```

结果如下：

![](https://i.loli.net/2021/10/24/BsG2xfWUymK54LH.png)

---

## 激活方法说明

以下内容均来自 MAS 项目的说明文档，对三种激活方式进行了简要的说明。在原文中也有说明许多内容只是猜测，此处仅供参考。

### HWID

使用该方法进行激活要满足以下几个条件：

- 仅支持 Win10 及 Win11。
- 机器处于联网状态。
- Windows Update Service（就是我们经常抱怨的 Windows 自动更新服务） 处于 Automatic 状态。 

当 Windows 版本从 Win7、Win8 或者 Win8.1 升级到 Win10（包括低版本 Win10 升级到更高版本的 Win10）时，已经激活的系统会自动获得一个数字许可（*Digital License*），该许可将会和用户**永久**绑定（通过用户的硬件或者用户的 Microsoft 账号），亦即我们所谓的「永久激活」。

这种方法的内部工作流程大致如下：

升级进程执行位于升级镜像中的 `gatherosstate.exe` 程序，该程序为后续流程生成一个 `Genuine Ticket`，该 ticket 是一个 xml 格式的文件，包含了以下内容：

{{< admonition type=quote title="GenuineAuthorization XML" open=true >}}

* Its version. As of now, this is always "1.0".
* genuineProperties:
  * Properties:
    * OA3xOriginalProductId - The Product ID of the BIOS key.
    * OA3xOriginalProductKey - The BIOS product key.
    * SessionId:
      * OSMajorVersion - The OS Version Major
      * OSMinorVersion - The OS Version Minor
      * OSPlatformId - The OS Platform ID. Always 2 (2 means Windows NT)
      * PP - Protected Process - Whether or not gatherosstate was run as a protected process 
  (It practically never does. ClipUp is also capable of generating those tickets, and it runs as a protected process.)
      * Hwid - The Hardware Id - a base64-encoded byte array containing information about the current hardware configuration.
      * Pfn - Package Family Name - The package family name of your Windows edition.
      * OA3xOriginalProductKey - The BIOS product key. (Yes, it's a duplicate).
      * DownlevelGenuineState - Indicates whether or not your system is genuine. (activated)
    * TimeStampClient - The ISO 8601 format date of ticket generation.
  * Signatures:
    * signature: (Either downlevelGTkey or clientLockboxKey depending on which utility actually generated the ticket - SLC, gatherosstate or ClipUp.)
      * downlevelGTkey - rsa-sha256 signature for the Properties field.
      * clientLockboxKey - rsa-sha256 signature for the Properties field.
  
{{< /admonition >}}

Client License Platform（ClipUp）程序会将上述 ticket 提交给微软服务器，并返回一个代表数字许可的 JSON。

该数字许可最终会绑定到用户当前的硬件上，若硬件进行了更换，则会通过 Microsoft 账号将数字许可迁移到新硬件上。

基于上述流程，两位大佬找到了一种手动生成 ticket 并交付给 `gatherosstate.exe` 进行数字许可申请的快速手段。

`gatherosstate.exe` 在执行过程中会加载 SLC（Software Licensing Client）动态库以获取当前机器的原许可信息，且 `gatherosstate.exe` 不会对该许可信息进行额外的检查认证，直接将这些信息封装入 ticket，提交到微软服务器。这里最关键的步骤就是 SLC 的动态替换，直接将合法的伪装 SLC 放置到 `gatherosstate.exe` 相同目录下，这时 `gatherosstate.exe` 就会使用该合法的伪装 SLC 进行数字许可申请，最终完成系统的激活。

最后，还有一个大家关心的问题：

{{< admonition type=quote title="FAQ" open=true >}}

微软能不能区分这些通过非正常方法获取的数字许可，并将它们回收或者禁用？

制作该工具的大佬也给出了他的解答：

Umm.. Yes, but actully no.

可以区分，但是实际上不会封禁。

微软在 ticket 中对于原先未激活的系统会设置 downlevelGTkey 标识，而正常激活过的系统会设置为 clientLockboxKey 标识。通过 MAS 工具进行申请时，我们伪装成了已经正常激活的系统，因此 ticket 中的标识为 clientLockboxKey。如果进行大面积的封禁，存在误封的风险。

**最重要的一点，微软不在意个人消费者的盗版行为，因为这不是它主要的收入来源。**

{{< /admonition >}}

### KMS38

这种方法与 HWID 方法流程基本一致，使用的工具一模一样，只是在 KMS38 ticket 中的时间字段。HWID 中使用的是 `Pfn` 字段，而在 KMS38 中使用的是 `GVLKExp`，它是 Generic Volume Key Expiration （date）的简写，是一个 ISO8601 标准的时间戳，表示 KMS 激活的到期时间（到2038年）。KMS38 最终并不会将 ticket 发送到微软服务器进行认证，而是发送到 KMS 服务器，MAS 提供了一个本地执行的服务器进行该认证操作。

KMS38 使用注意事项：

- 激活前，确保当前系统中不存在任何其他的 KMS 激活服务正在运行，若有则需要先卸载。
- 激活完成后，如果要使用 KMS 进行 Windows 其他产品的激活（如 Office），需要确保这些 KMS 能够兼容 KMS38，即不覆盖我们已经完成的 KMS38 激活（如果不能保证兼容，则需要执行 MAS 中的 KMS38 保护机制：进入主界面的 `6` 选项，选择 `[4] Protect / Unprotect KMS38 Activation`）。
- 这种方法生成的 ticket 仅适用于 Volume:GVLK 的系统，即 Enterprise 和 Education 版本。

### Online KMS

KMS（Key Management Service）是微软官方为政府、学校或公司等组织提供的一种批量授权手段，在组织中的机器（KMS Client）可以向组织内的 KMS Host Server 申请许可，而不是微软的授权服务器。这种方式的特点是：每次申请的许可最长过期时间为 180 天，且每隔 7 天，KMS Client 都会向 KMS Host Server 发起许可更新请求。

市面上许多的 KMS 激活工具都是在机器本地创建一个 KMS HOST Server，为自己本机提供激活服务，因此这些工具都需要在机器本地执行一个后台程序，从而导致一些病毒检测程序误杀误报。

同时，世界上还存在许多公用的 KMS Host Server，我们的 KMS Client 仅需要提供本机的一些信息（不敏感）给这些公用 Server，它们就会提供激活功能。这也是 Online KMS 使用的方法。它使用了一些常用的公共 Server，且保证了和 KMS38 方法的兼容性。

---

## 制作预激活镜像

平时我们对于系统的安装和激活总是先使用纯净镜像进行安装，安装完成进入系统后再手动执行激活操作。MAS 提供了一个预激活（Windows Pre-Activation）的方法，能够在系统安装完成的同时自动执行激活操作。

操作流程也非常简单，同样打开 `All-In-One-Version` 目录中的 cmd 脚本，选择 `6` 进入其他功能选项菜单，再选择 `[2] Extract $OEM$ Folder` 即可进入到预激活文件选择界面，如下图所示：

![](https://s2.loli.net/2022/01/26/YZGpbhXgKOJDSyw.png)

这里我们选择 `[4] HWID > KMS38`，它表示预激活先使用 HWID 方法，若激活失败，则降级到使用 KMS38（至于再次降级使用 Online KMS，个人认为没有必要），此时程序会在桌面上创建一个 `$OEM$` 目录，里面就包含了预激活脚本。

准备好 Windows ISO 纯净镜像，这里以 Win11 为例，打开 [官网](https://www.microsoft.com/en-us/software-download/windows11)，按照下图所示即可完成下载：

![](https://s2.loli.net/2022/01/31/R1MmzOGAt5Q7CZw.png)

使用 UltraISO、AnyBurn 等刻录工具打开你下载好的纯净 Windows ISO 镜像文件，将上述目录拷贝到镜像下的 `\sources` 目录，此时应该存在目录 `\sources\$OEM$`，记得保存，如下图所示：

![](https://i.loli.net/2021/10/24/G9EOzgTNjU75yhf.png)

至此，我们完成了预激活镜像的制作。

我在虚拟机进行了测试，使用刚制作好的预激活镜像进行系统安装（Win11 的安装需要联网并且登录微软账号），安装成功后，系统已是激活状态：

![](https://i.loli.net/2021/10/24/ifPvXcRoaZwQ7G2.png)

---

## 安全

MAS 提供了一份项目中使用到的所有不可读文件的病毒检测报告（检测平台：Virus Total）：

{{< admonition type=success title="Virus Total Report" open=true >}}


```
fabb5a0fc1e6a372219711152291339af36ed0b5 *gatherosstate.exe         Virus Total = 0/71
ca3a51fdfc8749b8be85f7904b1c238a6dfba135 *slc.dll                   Virus Total = 0/68
578364cb2319da7999acd8c015b4ce8da8f1b282 *ARM64_gatherosstate.exe   Virus Total = 0/69
5dbea3a580cf60391453a04a5c910a3ceca2b810 *ARM64_slc.dll             Virus Total = 0/67
```

**以下 exe 均为 Microsoft 官方提供的文件，因此即使检测报告数量不为 0，也并不用担心安全问题：**


```
48d928b1bec25a56fe896c430c2c034b7866aa7a *ClipUp.exe                Virus Total = 0/68
d30a0e4e5911d3ca705617d17225372731c770e2 *cleanosppx64.exe          Virus Total = 0/66
39ed8659e7ca16aaccb86def94ce6cec4c847dd6 *cleanosppx86.exe          Virus Total = 1/66
9d5b4b3e761cca9531d64200dfbbfa0dec94f5b0 *_Info.txt                 Virus Total = 0/59
```

{{< /admonition >}}

---

## 总结

- 如果是最常用的个人电脑，推荐直接使用 HWID 方法，保证联网和 Windows Update Service 正常运行这两个条件即可。
- 如果是一些特殊版本（如 Server、Enterprise等），则可以使用 KMS38。
- 如果要激活 Office，可以使用 Online KMS。
