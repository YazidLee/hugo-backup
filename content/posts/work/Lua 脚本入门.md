---
title: "Lua 脚本入门"
slug: "hello-lua"
summary: "东拼西凑之 Lua。"
author: ["SadBird"]
date: 2022-02-05T22:08:07+08:00
cover:
    image: "https://s2.loli.net/2022/02/05/qse7aYBtTA9xcju.png"
    alt: ""
categories: ["lua"]
tags: ["lua"]
katex: false
mermaid: false
draft: false
---

## 瞎折腾

在老笔记本上装上了 Manjaro，想整个 NeoVim 体验体验。NeoVim 内部集成了 Lua，许多插件及其配置都离不开 Lua，而且在 Redis 中也是使用 Lua 作为默认的脚本语言，到处都能看到它的身影，花点时间入个门还是挺合算的。

## Hello, world

第一个程序肯定是从 Hello World 开始了，但是首先要有 Lua 的执行环境。我还是在 Windows11 上进行学习，因此直接在[官网](http://luabinaries.sourceforge.net/)下载了二进制可执行文件，配置好环境变量就能直接用了，很简单。

新建 `hello.lua` 文件，写入以下代码，保存：

```lua
print('Hello, world!')
```

使用 `lua hello.lua` 就可以直接执行，在控制台输出结果。

## 基本语法

### 注释

```lua
-- 两个 - 符号表示单行注释

-- [[
  多行注释
-- ]]

-- 使用多行注释时，只要在第一个 -- 前增加一个 -，即可解除注释
--- [[
  此时已经取消注释
-- ]]
```

### Chunk

lua 中的 Chunk 表示**程序段**的概念，Chunk 既可以是一行简单的表达式也可以是由复杂函数、表达式共同组成的一组代码段。

### 变量

标志符由字母或下划线开头（下划线通常用于有特殊作用的内部变量），后面接数字、字母或下划线。

```lua
-- 行末没有分号

n = 1 -- lua5.2 及其之前的版本所有数值都是 64 位的 double 双精度浮点型，lua5.3 之后新增了 64 位的 integer 整型

s = 'string' -- 支持单引号字符串
ds = "string" -- 支持双引号字符串
ms = [[
    支持
    多行
    字符串.
]]
concat = s .. 'append' -- 字符串拼接使用 .. 操作符
print(concat)

t = nil -- 表示空值，类似于 java 中的 null，lua 同样提供了 GC 机制
print(undefined_variable) -- 使用未声明的变量，打印 nil，而非抛出异常，与 js 类似

-- type 函数返回变量类型，支持以下几种类型
-- nil
-- number
-- boolean
-- string
-- function
-- table 
-- thread
-- userdata

print(type(n)) -- number
print(type(false)) -- boolean
print(undefined_variable) -- nil
print(type(s)) -- string
print(type(ms)) -- string
print(type({})) -- table
print(type(print)) -- function
print(type(type)) -- thread
print(type(io.stdin)) -- userdata

-- 局部变量
local h

-- 多变量赋值
a, b = 2, 3
```

### 逻辑运算符

boolean 类型的值只有两个：true 和 false。但在 lua 中任何值都可以表示条件的真假。在 lua 语言中，条件测试（如 if 条件判断）将所有除了 false 和 nil 以外的值都视为 true，包括 0、空串、{} 等。

常用逻辑运算符包括：and、or 和 not，等值判断使用 `==` 符号，不等判断使用 `~=`。and 表示如果第一个操作数为 false，则返回第一个操作数；否则，返回第二个操作数。or 则表示如果第一个操作数为 true，则返回第一个操作数，否则返回第二个操作数。and 和 or 运算符都有短路的含义，只在特定条件下会触发第二个操作数的求值。not 返回值为 boolean 类型，操作数为 false 和 nil 时返回 true，其余情况下，not 返回值均为 false。

在 lua 中，or 有一个常见的用法：`x = x or y`，这个表达相当于：

```lua 
if not x then x = v end
```
表示当 x 未初始化时，将其初始化为 y。

### table

table 是 lua 语言中最为强大的类型，使用 talbe 可以表达我们常用的数组、字典等数据结构，可以类比到 js 中的 object。

table 最简单的创建方式如下：

```lua
v1 = 1
v2 = false
v3 = "lua"

t = {
  ["k1"] = v1,
  ["k2"] = v2,
  ["k3"] = v3
}

print(t["k1"])
print(t["k2"])
print(t["k3"])

-- 由于 k1、k2、k3 为简单字符串，lua 提供了以下简写
print(t.k1)
print(t.k2)
print(t.k3)

-- 索引 key 不仅仅可以是字符串，还可以是数字，甚至是表类型
t[1] = 100
t[{}] = "haha"
t[2.0] = "two"
print(t[2]) -- 打印 two，对于数值类型的索引 key，最终都会被转换为整型，如 2.0 -> 2

-- 以下对应两个不同的索引，不能混为一谈
t["10"] = "10"
t[10] = 20

-- for 遍历
for k, v in pairs(t) do
  print(k, v)
end
```

没有显式索引的情况下，table 可以作为数组（或称为序列）使用：

```lua
a = {"Monday", "Tuesday", "Wednesday", "Thurday", "Friday", "Saturday", "Sunday"}

-- 使用表的遍历方式，从结果中可以看出 index 索引从 1 开始
for index, v in ipairs(a) do
  print(index, v)
end

-- 第二种遍历方式，for 的步进形式，#a 表示 table 的长度
for k = 1, #a do
  print(k, a[k])
end

-- 步进默认为 1，调整为 2
for i = 1, #a, 2 do 
  print(i, a[i])
end

-- 注意 # 的使用，它一般用来获取 table 获 string 的长度（字节长度），在表末尾有 nil 时，末尾的 nil 不计入长度
print(#a) -- 返回 a 的长度
b = {10, 20, 30, nil, 50}
print(#b) -- 5，nil 不在末尾的情况
c = {10, 20, 30, 40, nil, nil}
print(#c) -- 4，末尾 nil 不计入总长度

-- 获取最后一个元素
last = a[#a]

-- 删除最后一个元素
a[#a] = nil

-- table 标准库 api
q = {10, 20, 30, 40}
table.insert(q, 1, 5) -- {5, 10, 20, 30, 40}
table.insert(q, 50) -- 不指定插入位置，默认在末尾插入，{5, 10, 20, 30, 40, 50}

table.remove(q, 2) -- 删除指定位置元素，并将后续元素往前移动，{5, 20, 30, 40, 50}

p = {}
table.move(q, 2, 4, 1, p) -- 将 q 中 2-4 位置处的元素拷贝到 p 中的 1 位置，若省略 p 参数，则是在 q 表内部移动
```

### Function

lua 的 function 可以直接类比 js 中的 function，它属于**第一类值（*first-class value*）**。这就意味着它与其他常见类型的值（如数字、字符串等）具有相同的权限，可以将 function 保存在变量或表中，也可以将 function 作为参数传递给其他 function。

```lua
-- function 的基本定义和使用
function myprint(a, b) 
  print(a, b)
end

myprint(a,b)

-- 参数个数不匹配时
myprint() -- nil    nil
myprint(1) -- 1    nil
myprint(1, 2, 3) -- 1    2（3 被忽略）

-- 多返回值
function maximun(a)
  local max_index = 1
  local max_value = a[max_index]

  for i = 1, #a do
    if a[i] > max_value then
      max_index = i
      max_value = a[i]
    end
  end
  
  return max_index, max_value
end

j, k = maximun({6, 9, 4, 15, 7, 20, 10}) 
print(j, k) -- 6    20

-- 可变长参数
function add(...)
  local sum = 0

  -- 使用 {...} 的方式可以将变长参数转换为 table
  for _, v in ipairs({...}) do
    sum = sum + v
  end

  return sum
end

print(add(1,2,3)) -- 6
print(add(1,2,3,4,5)) -- 15
```
## 扩展内容

### 闭包

同样与 JS 进行类比，上述对于 lua 函数的定义方式只是 lua 中提供的语法糖，本质上，函数的定义如下：
```lua
function func() print('hello world') end

-- 等价于

func = function() print('hello world') end
```

lua 函数的这种特性，可以将函数赋值给全局变量、局部变量或者表中的值。

```lua
a = {}
a.p = print -- 将 print 函数赋值给表 a 的 p 变量
a.p('hello world') -- 等同于 print('hello world')

-- 非全局函数
-- 以下几种方式等价
foo = {}
foo.bar = function(x) return 2 * x end

foo = {
  bar: function(x) return 2 * x end
}

foo = {}
function foo.bar(x) return 2 * x end

-- 将函数声明为局部函数
local function foo(x) return 2 * x end

-- 局部函数的声明问题
local function fib(n)
  if n <= 2 then return n end
  return fib(n - 1) + fib(n - 2) -- 此处有问题，fib 此时不可见
end
-- 需要写成以下方式
local fib
fib = function(n)
  if n <= 2 then return n end
  return fib(n - 1) + fib(n - 2) -- 解决上述问题
end
```
闭包是个比较难理解的概念，《Programming in Lua》中描述如下：

{{< admonition type=quote title="Closure" open=true >}}

Simply put, a closure is a function plus all it needs to access its upvalues correctly.

{{< /admonition >}}

这里又要引入 upvalue（上值）的概念，示例如下：
```lua
function newCounter() 
  local counter = 0 -- 既不是局部变量，也不是全局变量，在 lua 中称之为 upvalue
  return function() 
           counter = counter + 1
           return counter
         end
end 

c1 = newCounter()
print(c1()) -- 1
print(c1()) -- 2

c2 = newCounter() -- 新增计数器，创建了新的环境，不同于 c1，因此重新计数
print(c2()) -- 1
print(c2()) -- 2
```
上述代码中，`newCounter` 函数中定义了一个 `counter` 变量，它与普通局部变量最大的不同之处在于，当执行完 `c1 = newCounter()` 这句代码后，其实已经超出了 `counter` 的作用域，但是从后续 `c1()` 的两次调用中我们可以看到，仍然能够正常访问到 counter 的值，在 lua 中，类似 `counter` 的这种变量都被称为 upvalue（上值）。

闭包就是 `newCounter` 的匿名返回函数与该返回函数所在的一个上下文环境的统称（`counter` 就在该上下文环境中）。换句话说，实际上`newCounter` 返回的不仅仅是匿名函数本身，还包括了一个包含该匿名函数的上下文环境，环境中定义了一系列的 upvalue（若 `newCounter` 方法有参数，这些参数也属于 upvalue）。

闭包的应用场景较多，典型的一个应用是 GUI 交互的回调上，假设要做一个计算器的应用，需要 0-9 的数字按键，每个按键点击后需要在显示区域显示，因此可以定义如下函数：
```lua
function digitButton (digit)
  return Button{ label = digit,
                  action = function ()
                             add_to_display(digit)
                           end
  }
end
```
其中，digit 即为按键上的数值，这样每个按钮对应的数值都不相同，通过使用闭包，可以将所有按钮的逻辑统一。

### metatable

`metatable` 提供了对 table 的操作重载功能，比如现在有两个 table 分别代表两个分数，如下：
```lua 
f1 = {a = 1, b = 2} -- 表示 1/2
f2 = {a = 2, b = 3} -- 表示 2/3
```
现在想要定义一个加法操作，表示两个分数相加的逻辑，即 `result = f1 + f2`，使用 metatalbe 如下：
```lua
metafraction = {}
-- __add 是 lua 规定的 metamethod 之一，表示 + 号的重载
function metafraction.__add(f1, f2)
  sum = {}
  sum.b = f1.b * f2.b
  sum.a = f1.a * f2.b + f2.a * f1.b
  return sum
end

-- 设置 metatable，该 table 重载了 _add，为 f1 和 f2 提供了 + 号的重载操作
setmetatable(f1, metafraction)
setmetatable(f2, metafraction)
 
-- 直接使用 + 号进行分数的求和计算
s = f1 + f2
```
除了 `_add`，lua 还提供了许多可供选择的操作：

```lua
-- __add(a, b)                     for a + b
-- __sub(a, b)                     for a - b
-- __mul(a, b)                     for a * b
-- __div(a, b)                     for a / b
-- __mod(a, b)                     for a % b
-- __pow(a, b)                     for a ^ b
-- __unm(a)                        for -a
-- __concat(a, b)                  for a .. b
-- __len(a)                        for #a
-- __eq(a, b)                      for a == b
-- __lt(a, b)                      for a < b
-- __le(a, b)                      for a <= b
-- __index(a, b)  <fn or a table>  for a.b
-- __newindex(a, b, c)             for a.b = c
-- __call(a, ...)                  for a(...)
```
### 模块化

我们自定义一个 `mod.lua` 文件作为我们的模块，文件内容如下：
```lua
local M = {}

local function sayMyName()
  print('Hrunkner')
end

function M.sayHello()
  print('Why hello there')
  sayMyName()
end

return M
```
如果需要在另一个文件中引入该模块，则需要使用 `require`：

```lua
local mod = require('mod') -- 注意，没有.lua 后缀

mod.sayHello()
mod.sayMyName()

-- require 的作用可近似看为立即执行函数，但它有缓存机制，require 同一个模块只会执行一次

local mod = (function()
  -- <mod.lua 文件中的内容>
end)()
```
### 面向对象

lua 中没有提供内置的 Class 机制，但可以通过 table 和 metatable 实现面向对象的语义，其中 `__index` 的语义表示访问操作符 `.` 的重载（例如 table a 的 metatable 中设定了 __index 为 b，那么当使用 a.attr 访问 attr 时，会先在 table a 中查找，若 a 中没有，则会去 b 中查询 attr）：

```lua
-- Dog 类本质上是一个 table
Dog = {}
-- function t:fn(...) 是一个语法糖，相当于 function t.fn(self, ...)，只是在函数中添加了一个 self 参数
function Dog:new()
  -- 每次 new 生成一个新的 table
  newDog = {sound = "wang wang！"}
  -- 将第一个参数 self 的 __index 设定为 self 本身，表示 newDog 后续的查询范围是在本表内部
  self.__index = self
  -- setmetatable 返回设定好 metatable 的 newDog
  return setmetatable(newDog, self)
end

function Dog:makeSound()
  print('I say' .. self.sound)
end

-- 相当于 dogInstance = Dog.new(Dog)，相当于将新表 newDog 的 metatable 赋值为 Dog，并返回 newDog
dogInstance = Dog:new()
-- 相当于 newDog.makesound(newDog)，此时，makeSound 存在于 Dog 表中，由于设定了 metatable 的 __index，所以 在 newDog 中能访问到，且传入的 self 为 newDog,即 self = newDog
dogInstance:makeSound()

-- 类的继承
-- LoudDog = Dog.new(Dog)，因此 self 为 Dog，即 LoudDog 的 metatable.__index 为 Dog
LoudDog = Dog:new()                           

-- 重新定义 makeSound() 函数，注意这个函数此时是在 LoudDog 表中
function LoudDog:makeSound()
  s = self.sound .. ' '                       
  print(s .. s .. s)
end

-- LoudDog.new(LoudDog)，self 为 LoudDog，因此 seymour 的 metatable.__index 为 LoudDog
seymour = LoudDog:new()                       
-- seymour.makeSound(seymour)，由于 seymour 的 metatable.__index 为 LoudDog，因此调用的是 LoudDog 中的 makeSound，实现了覆盖
seymour:makeSound()  -- 'woof woof woof'      
```