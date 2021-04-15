---
title: 07:Java源码parseInt解析
author: Zhusong
layout: post
footer: true
category: Java
date: 2020-4-15
excerpt: "06:Java源码parseInt解析"
abstract: ""
---

# Integer.parseInt源码

```java
/**
 * Parses the string argument as a signed integer in the radix
 * specified by the second argument. The characters in the string
 * must all be digits of the specified radix (as determined by
 * whether {@link java.lang.Character#digit(char, int)} returns a
 * nonnegative value), except that the first character may be an
 * ASCII minus sign {@code '-'} ({@code '\u005Cu002D'}) to
 * indicate a negative value or an ASCII plus sign {@code '+'}
 * ({@code '\u005Cu002B'}) to indicate a positive value. The
 * resulting integer value is returned.
 *
 * <p>An exception of type {@code NumberFormatException} is
 * thrown if any of the following situations occurs:
 * <ul>
 * <li>The first argument is {@code null} or is a string of
 * length zero.
 *
 * <li>The radix is either smaller than
 * {@link java.lang.Character#MIN_RADIX} or
 * larger than {@link java.lang.Character#MAX_RADIX}.
 *
 * <li>Any character of the string is not a digit of the specified
 * radix, except that the first character may be a minus sign
 * {@code '-'} ({@code '\u005Cu002D'}) or plus sign
 * {@code '+'} ({@code '\u005Cu002B'}) provided that the
 * string is longer than length 1.
 *
 * <li>The value represented by the string is not a value of type
 * {@code int}.
 * </ul>
 *
 * <p>Examples:
 * <blockquote><pre>
 * parseInt("0", 10) returns 0
 * parseInt("473", 10) returns 473
 * parseInt("+42", 10) returns 42
 * parseInt("-0", 10) returns 0
 * parseInt("-FF", 16) returns -255
 * parseInt("1100110", 2) returns 102
 * parseInt("2147483647", 10) returns 2147483647
 * parseInt("-2147483648", 10) returns -2147483648
 * parseInt("2147483648", 10) throws a NumberFormatException
 * parseInt("99", 8) throws a NumberFormatException
 * parseInt("Kona", 10) throws a NumberFormatException
 * parseInt("Kona", 27) returns 411787
 * </pre></blockquote>
 *
 * @param      s   the {@code String} containing the integer
 *                  representation to be parsed
 * @param      radix   the radix to be used while parsing {@code s}.
 * @return     the integer represented by the string argument in the
 *             specified radix.
 * @exception  NumberFormatException if the {@code String}
 *             does not contain a parsable {@code int}.
 */
public static int parseInt(String s, int radix)
            throws NumberFormatException
{
    /*
     * WARNING: This method may be invoked early during VM initialization
     * before IntegerCache is initialized. Care must be taken to not use
     * the valueOf method.
     */

    if (s == null) {
        // Android-changed: Improve exception message for parseInt.
        throw new NumberFormatException("s == null");
    }

    if (radix < Character.MIN_RADIX) {
        throw new NumberFormatException("radix " + radix +
                                        " less than Character.MIN_RADIX");
    }

    if (radix > Character.MAX_RADIX) {
        throw new NumberFormatException("radix " + radix +
                                        " greater than Character.MAX_RADIX");
    }

    int result = 0;
    boolean negative = false;
    int i = 0, len = s.length();
    int limit = -Integer.MAX_VALUE;
    int multmin;
    int digit;

    if (len > 0) {
        char firstChar = s.charAt(0);
        if (firstChar < '0') { // Possible leading "+" or "-"
            if (firstChar == '-') {
                negative = true;
                limit = Integer.MIN_VALUE;
            } else if (firstChar != '+')
                throw NumberFormatException.forInputString(s);

            if (len == 1) // Cannot have lone "+" or "-"
                throw NumberFormatException.forInputString(s);
            i++;
        }
        multmin = limit / radix;
        while (i < len) {
            // Accumulating negatively avoids surprises near MAX_VALUE
            digit = Character.digit(s.charAt(i++),radix);
            if (digit < 0) {
                throw NumberFormatException.forInputString(s);
            }
            if (result < multmin) {
                throw NumberFormatException.forInputString(s);
            }
            result *= radix;
            if (result < limit + digit) {
                throw NumberFormatException.forInputString(s);
            }
            result -= digit;
        }
    } else {
        throw NumberFormatException.forInputString(s);
    }
    return negative ? result : -result;
}
```

# 原码、反码、补码

在计算机中，负数以其正值的补码形式表达, 正数的补码是其本身 正数的反码是其本身

二进制首位符号位(1表示负数, 0表示正数。)是人脑方便理解的, 机器的设计只有加法, 所以需要一个方式来实现 1 - 1 = 1 + (-1) = 0，所以有了__反码__，所以如果是 __使用原码/反码表示, int范围就是[-2^31 + 1, 2^31 - 1]__。但是有个特殊的数值0, 有+0/-0，+0/-0现实中没有意义。

> 1 - 1 = 1 + (-1) = [0000 0001]原 + [1000 0001]原= [0000 0001]反 + [1111 1110]反 = [1111 1111]反 = [1000 0000]原 = -0


__为了解决+0/-0问题引入了补码__

负数补码：负数的正值原码 => 反码(除符号位按位取反) => 补码(反码+1) [计算](https://www.23bei.com/tool-56.html)

> 1 - 1 = 1 + (-1) = [0000 0001]原 + [1000 0001]原= [0000 0001]补 + [1111 1111]补 = [0000 0000]补 = [1000 0000]原 = 0

原来的 __[1000 0000]补__ 可以用来表示比原最小负数 __[1111 1111]原 => [1000 0001]补__ 更小的值。

> (-1) + (-127) = [1000 0001]原 + [1111 1111]原 = [1111 1111]补 + [1000 0001]补 = [1000 0000]补 = -128

所以在 __使用补码表示, int范围就是[-2^31, 2^31 - 1]__

# 解析

## 判断正负

```java
char firstChar = s.charAt(0);
//  第一个是符号, 不是数字
if (firstChar < '0') { // Possible leading "+" or "-"
    // 负数
    if (firstChar == '-') {
        negative = true;
        limit = Integer.MIN_VALUE;
    } else if (firstChar != '+')
        throw NumberFormatException.forInputString(s);

    if (len == 1) // Cannot have lone "+" or "-"
        throw NumberFormatException.forInputString(s);
    // 其他默认就是正数
    i++;
}
```

## 变量含义

### 1. limit

包括符号位在内的边界值

```java
int limit = -Integer.MAX_VALUE;
	
if (firstChar == '-') {
    negative = true;
    // 负数更改为MIN_VALUE
    limit = Integer.MIN_VALUE;
}
```

为什么是最开始是用-MAX\_VALUE, 如果是负数就更换成MIN\_VALUE？

MAX\_VALUE：2^31-1

MIN\_VALUE：-2^31

因为负数表示的范围比正数的范围多一位, 即之前补码里最小的值[1000 .... 000]补, 在后续计算中不容易溢出错误。

### 2. multmin

最小乘积值, 就是最小的负数除以radix得到的, 在不超过limit的情况下可以做乘积最小的值。如果比他还小, 下一次乘积radix就超出limit的范围了。

### 3. digit
每一位的正值

## 计算原理

```java
while (i < len)
	digit = Character.digit(s[i++], radix)
	result *= radix;
	result -= digit;
}
```
以10进制123转换公式为例：

0(result0) *  10 - 1(digit0)  
= -1

-1(result1) * 10 - 2(digit1)  
= (0(result0) *  10 - 1(digit0) ) * 10 -2(digit1)  
= -(1 * 10) - 2
= -12

-12(result2) * 10 - 3(digit3)  
= (-1(result1) * 10 - 2(digit1)) * 10 - 3(digit3)  
= (-1((0(result0) * 10 - 1(digit0)) * 10 -2(digit1)) * 10) - 3(digit3)  
= -(1 * 10^2) - (2 * 10^1) - 3  
= -123

其实就是按照转换规则:

digitn * radix^(n-1) + ... + digit0 * radix^0 = value

## 理解

主要是这里的负数值, 需要理解下补码，保证不会漏掉补码的最小值。




