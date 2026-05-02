#!/bin/bash

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
  echo "Error: 请使用 root 权限运行此脚本 (Please run as root)"
  exit 1
fi

SIZE=$1

# 检查是否传入了参数
if [ -z "$SIZE" ]; then
  echo "Usage: bash swap.sh <size>"
  echo "Examples:"
  echo "  bash swap.sh 1G    # 创建 1GB 的 swap"
  echo "  bash swap.sh 512M  # 创建 512MB 的 swap"
  echo "  bash swap.sh 0     # 关闭并彻底删除 swap"
  exit 1
fi

echo "========================================"
echo " Swap 自动配置与管理脚本"
echo "========================================"

# 第一步：检查并清理已存在的 /swapfile
if [ -f /swapfile ] || grep -q "/swapfile" /proc/swaps; then
  echo "-> 正在关闭旧的 /swapfile..."
  swapoff /swapfile 2>/dev/null
  echo "-> 正在删除旧的 /swapfile..."
  rm -f /swapfile
fi

# 第二步：处理关闭 Swap 的需求 (0, 0G, 0M, off, disable 等)
if [[ "$SIZE" =~ ^0[a-zA-Z]*$ ]] || [[ "${SIZE,,}" == "off" ]] || [[ "${SIZE,,}" == "disable" ]]; then
  echo "-> 正在从 /etc/fstab 中移除开机自启项..."
  sed -i '/\/swapfile/d' /etc/fstab
  echo "========================================"
  echo "完成！Swap 已被完全关闭和清理。"
  free -h
  exit 0
fi

# 第三步：创建新的 Swap 文件
echo "-> 正在分配 $SIZE 的 Swap 空间..."

# 优先使用 fallocate (速度快)，如果失败则降级使用 dd (兼容性好)
if ! fallocate -l "$SIZE" /swapfile 2>/dev/null; then
    echo "-> fallocate 分配失败，尝试使用 dd 命令兜底创建 (这可能需要一点时间)..."
    
    # 提取数字和单位用于 dd
    if [[ "$SIZE" =~ ^([0-9]+)G$ ]]; then
        MB=$((${BASH_REMATCH[1]} * 1024))
    elif [[ "$SIZE" =~ ^([0-9]+)M$ ]]; then
        MB=${BASH_REMATCH[1]}
    else
        echo "Error: 使用 dd 兜底失败，无法识别的大小格式。请明确使用大写 M 或 G (如 1G, 512M)。"
        exit 1
    fi
    dd if=/dev/zero of=/swapfile bs=1M count=$MB status=progress
fi

echo "-> 正在设置安全权限 (600)..."
chmod 600 /swapfile

echo "-> 正在格式化 Swap 空间..."
mkswap /swapfile

echo "-> 正在启用 Swap..."
swapon /swapfile

# 第四步：写入 /etc/fstab 保证开机自启
if ! grep -q "^/swapfile" /etc/fstab; then
  echo "-> 正在添加开机自启项到 /etc/fstab..."
  echo "/swapfile none swap sw 0 0" >> /etc/fstab
fi

echo "========================================"
echo "完成！你现在有了一个 $SIZE 大小的 swap 文件 (/swapfile)"
echo "当前内存和 Swap 状态如下："
free -h
