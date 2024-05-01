#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# Modify default IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate
m=$(sed -n '/define Device\/tl-wr703n-v1/=' target/linux/ar71xx/image/tp-link.mk)
let m=m+1
sed -i $m'd' target/linux/ar71xx/image/tp-link.mk
sed -i $m' i\  \$(Device/tplink-16mlzma)' target/linux/ar71xx/image/tp-link.mk

#cd ..
#cp -r package/upx3.95/* openwrt/tools
#sed -i -e '/upx/d' openwrt/tools/Makefile
#m=$(sed -n '/tools-y +=/=' openwrt/tools/Makefile)
#m=$(echo $m|cut -d' ' -f1)
#sed -i $m' itools-y += ucl upx' openwrt/tools/Makefile
#sed -i '/# builddir dependencies/a\\$(curdir)\/upx\/compile := \$(curdir)\/ucl\/compile' openwrt/tools/Makefile
