#!/bin/bash

# 测试直接搜索联系人功能

echo "=== 测试直接搜索联系人功能 ==="
echo ""

# 获取所有联系人
echo "1. 获取所有联系人:"
all_contacts=($(get_all_contacts))
echo "共找到 ${#all_contacts[@]} 个联系人"
echo ""

# 测试过滤联系人
echo "2. 测试过滤联系人:"
search_query="abcd"
echo "搜索关键词: $search_query"

filtered_contacts=()
for contact_item in "${all_contacts[@]}"; do
    local category=$(echo "$contact_item" | cut -d':' -f1)
    local contact=$(echo "$contact_item" | cut -d':' -f2)
    if echo "$contact" | grep -i "$search_query" >/dev/null 2>&1; then
        filtered_contacts+=($contact_item)
    fi
done

echo "找到 ${#filtered_contacts[@]} 个匹配的联系人:"
for contact_item in "${filtered_contacts[@]}"; do
    local category=$(echo "$contact_item" | cut -d':' -f1)
    local contact=$(echo "$contact_item" | cut -d':' -f2)
    echo "  $contact (${category})"
done

echo ""
echo "=== 测试完成 ==="
