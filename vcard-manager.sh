#!/bin/bash

# vCard 联系人管理工具 - 纯 Bash 实现
# 用于管理 data 目录下的 YAML 联系人数据

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 数据目录
DATA_DIR="./data"

# 分页默认值
DEFAULT_PAGE_SIZE=10
current_page_size=$DEFAULT_PAGE_SIZE

# 检查数据目录是否存在
if [ ! -d "$DATA_DIR" ]; then
    echo -e "${RED}错误: 数据目录 '$DATA_DIR' 不存在${NC}"
    exit 1
fi

# 获取所有分类
function get_categories() {
    ls -l "$DATA_DIR" | grep ^d | awk '{print $9}'
}

# 获取分类下的所有 YAML 文件
function get_yaml_files() {
    local category="$1"
    local category_path="$DATA_DIR/$category"
    
    if [ ! -d "$category_path" ]; then
        return 1
    fi
    
    ls "$category_path"/*.yaml 2>/dev/null | sed "s:.*/::;s/\.yaml\$//"
}

# 读取 YAML 文件内容
function read_yaml() {
    local category="$1"
    local filename="$2"
    local file_path="$DATA_DIR/$category/$filename.yaml"
    
    if [ ! -f "$file_path" ]; then
        echo -e "${RED}错误: 文件 '$file_path' 不存在${NC}" >&2
        return 1
    fi
    
    cat "$file_path"
}

# 获取所有联系人（包含分类信息）
function get_all_contacts() {
    local -a all_contacts=()
    
    # 遍历所有分类
    local categories=($(get_categories))
    for category in "${categories[@]}"; do
        # 获取该分类下的所有联系人
        local contacts=($(get_yaml_files "$category"))
        for contact in "${contacts[@]}"; do
            # 保存格式为 "分类:联系人"，方便后续处理
            all_contacts+=("$category:$contact")
        done
    done
    
    echo "${all_contacts[@]}"
}

# 解析 YAML 中的字段值
function get_yaml_field() {
    local yaml_content="$1"
    local field="$2"
    
    # 提取basic块
    basic=$(echo "$yaml_content" | grep -A 40 "^basic:")
    
    # 检查是简单字段还是数组字段
    if echo "$basic" | grep -q "^  $field: " 2>/dev/null; then
        # 简单字段
        echo "$basic" | grep "^  $field: " | sed -E "s/^  $field:[[:space:]]*'?([^']*)'?[[:space:]]*$/\1/"
    else
        # 数组字段 - 使用更可靠的方式提取
        echo "$basic" | awk -v field="$field" '{
            # 检查字段开始 (注意：字段名前有两个空格，冒号后可能有换行)
            if ($0 ~ "^  " field ":") {
                in_array = 1;
                next;
            }
            
            if (in_array) {
                # 检查数组项 (四个空格加一个减号)
                if ($0 ~ /^    - /) {
                    # 提取值，移除单引号和前导/尾随空格
                    gsub(/^    -[[:space:]]*'\''?/, "");
                    gsub(/'\''?[[:space:]]*$/, "");
                    print;
                }
                # 检查下一个字段开始 (两个空格加字母)
                else if ($0 ~ /^  [a-zA-Z]/) {
                    exit;
                }
            }
        }'
    fi
}

# 编辑数组字段函数
function edit_array_field() {
    local field_name="$1"
    local current_values="$2"  # 换行分隔的字符串
    local -a values_array=()
    
    # 检查输入参数
    if [ -z "$current_values" ]; then
        values_array=()
    else
        # 将换行分隔的字符串转换为数组
        while IFS= read -r line; do
            if [ -n "$line" ]; then  # 只添加非空行
                values_array+=($line)
            fi
        done <<< "$current_values"
    fi
    
    while true; do
        clear
        # 将所有状态输出重定向到标准错误，这样它们会显示在终端上
        echo -e "${BLUE}=====================================${NC}" >&2
        echo -e "${BLUE}        编辑 $field_name${NC}" >&2
        echo -e "${BLUE}=====================================${NC}" >&2
        
        # 显示当前值
        echo -e "${YELLOW}当前 $field_name:${NC}" >&2
        if [ ${#values_array[@]} -eq 0 ]; then
            echo -e "${RED}无${NC}" >&2
        else
            for ((i=0; i<${#values_array[@]}; i++)); do
                echo -e "${YELLOW}$((i+1)). ${values_array[$i]}${NC}" >&2
            done
        fi
        echo -e "${BLUE}-------------------------------------${NC}" >&2
        
        # 显示操作菜单
        echo -e "${YELLOW}请选择操作:${NC}" >&2
        echo -e "${YELLOW}1. 添加新$field_name${NC}" >&2
        echo -e "${YELLOW}2. 修改现有$field_name${NC}" >&2
        echo -e "${YELLOW}3. 删除现有$field_name${NC}" >&2
        echo -e "${YELLOW}4. 保存并返回${NC}" >&2
        echo -e "${YELLOW}5. 取消编辑${NC}" >&2
        echo -e "${BLUE}-------------------------------------${NC}" >&2
        
        # read命令直接输出到终端
        read -p "请输入选择 [1-5]: " choice
        
        case "$choice" in
            1)  # 添加新值
                read -p "请输入新$field_name: " new_value
                if [ -n "$new_value" ]; then
                    values_array+=($new_value)
                    echo -e "${GREEN}已添加$field_name: ${new_value}${NC}" >&2
                    sleep 1
                fi
                ;;
            2)  # 修改现有值
                if [ ${#values_array[@]} -eq 0 ]; then
                    echo -e "${RED}没有可修改的$field_name${NC}" >&2
                    sleep 1
                    continue
                fi
                read -p "请输入要修改的$field_name编号: " idx
                if [ "$idx" -ge 1 ] && [ "$idx" -le ${#values_array[@]} ]; then
                    local current_value="${values_array[$((idx-1))]}"
                    read -p "请输入新的$field_name [${current_value}] (直接回车保持不变): " new_value
                    if [ -n "$new_value" ]; then
                        values_array[$((idx-1))]="$new_value"
                        echo -e "${GREEN}$field_name已更新为: ${new_value}${NC}" >&2
                        sleep 1
                    else
                        echo -e "${YELLOW}$field_name保持不变: ${current_value}${NC}" >&2
                        sleep 1
                    fi
                else
                    echo -e "${RED}无效的编号${NC}" >&2
                    sleep 1
                fi
                ;;
            3)  # 删除现有值
                if [ ${#values_array[@]} -eq 0 ]; then
                    echo -e "${RED}没有可删除的$field_name${NC}" >&2
                    sleep 1
                    continue
                fi
                read -p "请输入要删除的$field_name编号: " idx
                if [ "$idx" -ge 1 ] && [ "$idx" -le ${#values_array[@]} ]; then
                    local deleted_value="${values_array[$((idx-1))]}"
                    unset values_array[$((idx-1))]
                    # 重新索引数组
                    values_array=(${values_array[@]})
                    echo -e "${GREEN}已删除$field_name: ${deleted_value}${NC}" >&2
                    sleep 1
                else
                    echo -e "${RED}无效的编号${NC}" >&2
                    sleep 1
                fi
                ;;
            4)  # 保存并返回
                # 将数组转换为换行分隔的字符串
                local result=""
                for value in "${values_array[@]}"; do
                    result+="$value"$'\n'
                done
                # 去除末尾换行
                result=${result%$'\n'}
                # 只有最终结果使用标准输出，被捕获到变量中
                echo "$result"
                return 0
                ;;
            5)  # 取消编辑
                return 1
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}" >&2
                sleep 1
                ;;
        esac
    done
}

# 生成 YAML 内容
function generate_yaml() {
    local organization="$1"
    local cell_phone="$2"
    local url="$3"
    local work_email="$4"
    
    cat <<EOF
basic:
  organization: $organization
  cellPhone:
$(echo "$cell_phone" | awk '{print "    - " $0}')
$(if [ -n "$url" ]; then echo "  url: $url"; fi)
$(if [ -n "$work_email" ]; then 
    echo "  workEmail:";
    echo "$work_email" | awk '{print "    - " $0}';
fi)
EOF
}

# 保存 YAML 文件
function save_yaml() {
    local category="$1"
    local filename="$2"
    local content="$3"
    local file_path="$DATA_DIR/$category/$filename.yaml"
    
    echo "$content" > "$file_path"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}文件保存成功: $file_path${NC}"
        return 0
    else
        echo -e "${RED}文件保存失败${NC}"
        return 1
    fi
}

# 通用分页选择函数 - 用于创建、编辑、删除功能
function select_item_paginated() {
    local original_items=($1)
    local filtered_items=(${original_items[@]})
    local prompt="$2"
    local title="$3"
    local show_cancel="$4"
    local search_query=""
    
    local total_items=${#filtered_items[@]}
    local total_pages=$(( (total_items + current_page_size - 1) / current_page_size ))
    local current_page=1
    
    while true; do
        clear
        echo -e "${BLUE}=====================================${NC}"
        echo -e "${BLUE}            $title${NC}"
        echo -e "${BLUE}=====================================${NC}"
        
        # 顶部快捷操作栏
        if [ "$show_cancel" = true ]; then
            echo -e "${YELLOW}【快捷操作】: m.返回主菜单 | q.退出程序 | c.取消 | f.搜索 | s.自定义每页显示数量 (当前: $current_page_size)${NC}"
        else
            echo -e "${YELLOW}【快捷操作】: m.返回主菜单 | q.退出程序 | f.搜索 | s.自定义每页显示数量 (当前: $current_page_size)${NC}"
        fi
        
        # 显示搜索状态
        if [ -n "$search_query" ]; then
            echo -e "${YELLOW}【搜索中】: '$search_query' (按 f 清空搜索)${NC}"
        fi
        
        echo -e "${BLUE}-------------------------------------${NC}"
        
        echo -e "${YELLOW}$prompt${NC}"
        echo -e "${YELLOW}第 $current_page/$total_pages 页，共 $total_items 项${NC}"
        echo -e "${BLUE}-------------------------------------${NC}"
        
        # 计算当前页的起始和结束索引
        local start_idx=$(( (current_page - 1) * current_page_size ))
        local end_idx=$(( start_idx + current_page_size - 1 ))
        if [ $end_idx -ge $total_items ]; then
            end_idx=$((total_items - 1))
        fi
        
        # 显示当前页的项目
        for ((i=start_idx; i<=end_idx; i++)); do
            echo -e "${YELLOW}$((i+1)). ${filtered_items[$i]}${NC}"
        done
        
        # 显示分页导航
        echo -e "${BLUE}-------------------------------------${NC}"
        echo -e "${YELLOW}分页导航: p.上一页 | n.下一页${NC}"
        
        # 读取用户选择
        read -p "请输入选择: " choice
        
        # 处理字母快捷操作
        case "$choice" in
            [mM]) show_main_menu; return 1 ;;
            [qQ]) echo -e "${GREEN}谢谢使用！${NC}"; exit 0 ;;
            [cC]) if [ "$show_cancel" = true ]; then return 2 ; fi ;;
            [fF]) # 处理搜索功能
                  read -p "请输入搜索关键词 (直接回车清空搜索): " search_query
                  if [ -n "$search_query" ]; then
                      # 过滤项目列表，支持模糊搜索
                      filtered_items=()
                      for item in "${original_items[@]}"; do
                          if echo "$item" | grep -i "$search_query" >/dev/null 2>&1; then
                              filtered_items+=($item)
                          fi
                      done
                  else
                      # 清空搜索，恢复原始列表
                      filtered_items=(${original_items[@]})
                  fi
                  # 重新计算分页信息
                  total_items=${#filtered_items[@]}
                  total_pages=$(( (total_items + current_page_size - 1) / current_page_size ))
                  current_page=1
                  continue ;;
            [sS]) read -p "请输入每页显示数量: " new_size
                  if [ "$new_size" -gt 0 ] 2>/dev/null; then
                      current_page_size=$new_size
                      # 重新计算分页信息
                      total_pages=$(( (total_items + current_page_size - 1) / current_page_size ))
                      current_page=1
                  else
                      echo -e "${RED}无效的数量，请输入大于0的数字${NC}"
                      sleep 1
                  fi
                  continue ;;
            [nN]) if [ $current_page -lt $total_pages ]; then
                      current_page=$((current_page + 1))
                  else
                      echo -e "${YELLOW}已经是最后一页${NC}"
                      sleep 1
                  fi
                  continue ;;
            [pP]) if [ $current_page -gt 1 ]; then
                      current_page=$((current_page - 1))
                  else
                      echo -e "${YELLOW}已经是第一页${NC}"
                      sleep 1
                  fi
                  continue ;;
        esac
        
        # 处理数字选择
        if [ "$choice" -ge 1 ] && [ "$choice" -le $total_items ]; then
            echo "${filtered_items[$((choice-1))]}"
            return 0
        else
            echo -e "${RED}无效选择，请重新输入${NC}"
            sleep 1
            continue
        fi
    done
}

# 删除 YAML 文件（包括关联的 PNG）
function delete_yaml() {
    local category="$1"
    local filename="$2"
    local yaml_path="$DATA_DIR/$category/$filename.yaml"
    local png_path="$DATA_DIR/$category/$filename.png"
    
    if [ -f "$yaml_path" ]; then
        rm "$yaml_path"
        echo -e "${GREEN}已删除: $yaml_path${NC}"
    fi
    
    if [ -f "$png_path" ]; then
        rm "$png_path"
        echo -e "${GREEN}已删除: $png_path${NC}"
    fi
}

# 显示主菜单
function show_main_menu() {
    clear
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}        vCards CN 管理工具${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${YELLOW}1. 查看联系人 (v)${NC}"
    echo -e "${YELLOW}2. 创建联系人 (c)${NC}"
    echo -e "${YELLOW}3. 编辑联系人 (e)${NC}"
    echo -e "${YELLOW}4. 删除联系人 (d)${NC}"
    echo -e "${YELLOW}5. 退出 (q)${NC}"
    echo -e "${BLUE}=====================================${NC}"
    
    read -p "请输入选择 [1-5] 或 [v/c/e/d/q]: " choice
    
    case $choice in
        1 | [vV]) view_contacts ;;
        2 | [cC]) create_contact ;;
        3 | [eE]) edit_contact ;;
        4 | [dD]) delete_contact ;;
        5 | [qQ]) echo -e "${GREEN}谢谢使用！${NC}"; exit 0 ;;
        *) echo -e "${RED}无效选择，请重新输入${NC}"; sleep 1; show_main_menu ;;
    esac
}

# 查看联系人
function view_contacts() {
    clear
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}            查看联系人${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${YELLOW}1. 按分类查看${NC}"
    echo -e "${YELLOW}2. 直接搜索所有联系人${NC}"
    echo -e "${BLUE}-------------------------------------${NC}"
    echo -e "${YELLOW}【快捷操作】: m.返回主菜单 | q.退出程序${NC}"
    echo -e "${BLUE}-------------------------------------${NC}"
    
    read -p "请输入选择: " choice
    
    case $choice in
        [mM]) show_main_menu; return ;; 
        [qQ]) echo -e "${GREEN}谢谢使用！${NC}"; exit 0 ;; 
        1) show_categories=true ;; 
        2) direct_search=true ;; 
        *) echo -e "${RED}无效选择，请重新输入${NC}"; sleep 1; view_contacts; return ;; 
    esac
    
    if [ "$direct_search" = true ]; then
        # 直接搜索所有联系人
        local all_contacts=($(get_all_contacts))
        if [ ${#all_contacts[@]} -eq 0 ]; then
            echo -e "${RED}没有找到联系人${NC}"
            read -p "按 Enter 键返回主菜单..." -n 1
            show_main_menu
            return
        fi
        
        # 分页显示所有联系人
        local original_contacts=(${all_contacts[@]})
        local filtered_contacts=(${original_contacts[@]})
        local search_query=""
        local total_contacts
        local total_pages
        local current_page
        total_contacts=${#filtered_contacts[@]}
        total_pages=$(( (total_contacts + current_page_size - 1) / current_page_size ))
        current_page=1
        
        while true; do
            clear
            echo -e "${BLUE}=====================================${NC}"
            echo -e "${BLUE}        直接搜索查看联系人${NC}"
            echo -e "${BLUE}=====================================${NC}"
            echo -e "${YELLOW}【快捷操作】: m.返回主菜单 | q.退出程序 | f.搜索 | s.自定义每页显示数量 (当前: $current_page_size)${NC}"
            
            # 显示搜索状态
            if [ -n "$search_query" ]; then
                echo -e "${YELLOW}【搜索中】: '$search_query' (按 f 清空搜索)${NC}"
            fi
            
            echo -e "${BLUE}-------------------------------------${NC}"
            echo -e "${YELLOW}请选择联系人:${NC}"
            echo -e "${YELLOW}第 $current_page/$total_pages 页，共 $total_contacts 个联系人${NC}"
            echo -e "${BLUE}-------------------------------------${NC}"
            
            # 计算当前页的起始和结束索引
            local start_idx=$(( (current_page - 1) * current_page_size ))
            local end_idx=$(( start_idx + current_page_size - 1 ))
            if [ $end_idx -ge $total_contacts ]; then
                end_idx=$((total_contacts - 1))
            fi
            
            # 显示当前页的联系人
            for ((i=start_idx; i<=end_idx; i++)); do
                # 显示格式为 "分类:联系人"，但只显示联系人名称
                local contact_info=${filtered_contacts[$i]}
                local contact_name=${contact_info#*:}
                echo -e "${YELLOW}$((i+1)). ${contact_name}${NC}"
            done
            
            # 显示分页导航
            echo -e "${BLUE}-------------------------------------${NC}"
            echo -e "${YELLOW}分页导航: p.上一页 | n.下一页${NC}"
            
            # 读取用户选择
            read -p "请输入选择: " choice
            
            # 处理字母快捷操作
            case "$choice" in
                [mM]) show_main_menu; return ;; 
                [qQ]) echo -e "${GREEN}谢谢使用！${NC}"; exit 0 ;; 
                [fF]) # 处理搜索功能
                      read -p "请输入搜索关键词 (直接回车清空搜索): " search_query
                      if [ -n "$search_query" ]; then
                          # 过滤联系人列表，支持模糊搜索
                          filtered_contacts=()
                          for contact in "${original_contacts[@]}"; do
                              local contact_name=${contact#*:}
                              if echo "$contact_name" | grep -i "$search_query" >/dev/null 2>&1; then
                                  filtered_contacts+=($contact)
                              fi
                          done
                      else
                          # 清空搜索，恢复原始列表
                          filtered_contacts=(${original_contacts[@]})
                      fi
                      # 重新计算分页信息
                      total_contacts=${#filtered_contacts[@]}
                      total_pages=$(( (total_contacts + current_page_size - 1) / current_page_size ))
                      current_page=1
                      continue ;; 
                [sS]) read -p "请输入每页显示数量: " new_size
                      if [ "$new_size" -gt 0 ] 2>/dev/null; then
                          current_page_size=$new_size
                          # 重新计算分页信息
                          total_contacts=${#filtered_contacts[@]}
                          total_pages=$(( (total_contacts + current_page_size - 1) / current_page_size ))
                          current_page=1
                      else
                          echo -e "${RED}无效的数量，请输入大于0的数字${NC}"
                          sleep 1
                      fi
                      continue ;; 
                [nN]) if [ $current_page -lt $total_pages ]; then current_page=$((current_page + 1)); else echo -e "${YELLOW}已经是最后一页${NC}"; sleep 1; fi; continue ;; 
                [pP]) if [ $current_page -gt 1 ]; then current_page=$((current_page - 1)); else echo -e "${YELLOW}已经是第一页${NC}"; sleep 1; fi; continue ;; 
            esac
            
            # 处理数字选择
            if [ "$choice" -ge 1 ] && [ "$choice" -le $total_contacts ]; then
                local contact_info=${filtered_contacts[$((choice-1))]}
                local category=${contact_info%%:*}
                local contact=${contact_info#*:}
                
                # 显示联系人详情
                clear
                echo -e "${BLUE}=====================================${NC}"
                echo -e "${BLUE}        联系人详情${NC}"
                echo -e "${BLUE}=====================================${NC}"
                
                yaml_content=$(read_yaml "$category" "$contact")
                organization=$(get_yaml_field "$yaml_content" "organization")
                cell_phone=$(get_yaml_field "$yaml_content" "cellPhone" | tr '\n' ', ' | sed 's/,$//')
                url=$(get_yaml_field "$yaml_content" "url")
                work_email=$(get_yaml_field "$yaml_content" "workEmail" | tr '\n' ', ' | sed 's/,$//')
                
                echo -e "${YELLOW}组织名称:${NC} $organization"
                echo -e "${YELLOW}电话号码:${NC} ${cell_phone:-无}"
                echo -e "${YELLOW}网址:${NC} ${url:-无}"
                echo -e "${YELLOW}邮箱:${NC} ${work_email:-无}"
                echo -e "${BLUE}=====================================${NC}"
                
                read -p "按 Enter 键返回..." -n 1
                continue
            else
                echo -e "${RED}无效选择，请重新输入${NC}"; sleep 1; continue
            fi
        done
    else
        local show_categories=${show_categories:-true}
        local selected_category=""
        
        while true; do
            clear
            echo -e "${BLUE}=====================================${NC}"
            if [ "$show_categories" = true ]; then
                echo -e "${BLUE}            查看联系人${NC}"
            else
                echo -e "${BLUE}          分类: $selected_category${NC}"
            fi
            echo -e "${BLUE}=====================================${NC}"
            
            # 顶部快捷操作栏
            if [ "$show_categories" = true ]; then
                echo -e "${YELLOW}【快捷操作】: m.返回主菜单 | q.退出程序 | s.自定义每页显示数量 (当前: $current_page_size)${NC}"
            else
                echo -e "${YELLOW}【快捷操作】: m.返回主菜单 | b.返回分类列表 | q.退出程序 | s.自定义每页显示数量 (当前: $current_page_size)${NC}"
            fi
            echo -e "${BLUE}-------------------------------------${NC}"
            
            if [ "$show_categories" = true ]; then
                # 获取分类列表
                categories=($(get_categories))
                if [ ${#categories[@]} -eq 0 ]; then
                    echo -e "${RED}没有找到分类${NC}"
                    read -p "按 Enter 键返回主菜单..." -n 1
                    show_main_menu
                    return
                fi
                
                # 分页显示分类
                    local original_categories=(${categories[@]})
                    local filtered_categories=(${original_categories[@]})
                    local search_query=""
                    local total_categories
                    local total_pages
                    local current_page
                    total_categories=${#filtered_categories[@]}
                    total_pages=$(( (total_categories + current_page_size - 1) / current_page_size ))
                    current_page=1
                    
                    while true; do
                        clear
                        echo -e "${BLUE}=====================================${NC}"
                        echo -e "${BLUE}            查看联系人${NC}"
                        echo -e "${BLUE}=====================================${NC}"
                        echo -e "${YELLOW}【快捷操作】: m.返回主菜单 | q.退出程序 | f.搜索 | s.自定义每页显示数量 (当前: $current_page_size)${NC}"
                        
                        # 显示搜索状态
                        if [ -n "$search_query" ]; then
                            echo -e "${YELLOW}【搜索中】: '$search_query' (按 f 清空搜索)${NC}"
                        fi
                        
                        echo -e "${BLUE}-------------------------------------${NC}"
                        echo -e "${YELLOW}请选择分类:${NC}"
                        echo -e "${YELLOW}第 $current_page/$total_pages 页，共 $total_categories 个分类${NC}"
                        echo -e "${BLUE}-------------------------------------${NC}"
                    
                    # 计算当前页的起始和结束索引
                    local start_idx=$(( (current_page - 1) * current_page_size ))
                    local end_idx=$(( start_idx + current_page_size - 1 ))
                    if [ $end_idx -ge $total_categories ]; then
                        end_idx=$((total_categories - 1))
                    fi
                    
                    # 显示当前页的分类
                    for ((i=start_idx; i<=end_idx; i++)); do
                        echo -e "${YELLOW}$((i+1)). ${filtered_categories[$i]}${NC}"
                    done
                    
                    # 显示分页导航
                    echo -e "${BLUE}-------------------------------------${NC}"
                    echo -e "${YELLOW}分页导航: p.上一页 | n.下一页${NC}"
                    
                    # 读取用户选择
                    read -p "请输入选择: " choice
                    
                    # 处理字母快捷操作
                    case "$choice" in
                        [mM]) show_main_menu; return ;; 
                        [qQ]) echo -e "${GREEN}谢谢使用！${NC}"; exit 0 ;; 
                        [fF]) # 处理搜索功能
                              read -p "请输入搜索关键词 (直接回车清空搜索): " search_query
                              if [ -n "$search_query" ]; then
                                  # 过滤分类列表，支持模糊搜索
                                  filtered_categories=()
                                  for category in "${original_categories[@]}"; do
                                      if echo "$category" | grep -i "$search_query" >/dev/null 2>&1; then
                                          filtered_categories+=($category)
                                      fi
                                  done
                              else
                                  # 清空搜索，恢复原始列表
                                  filtered_categories=(${original_categories[@]})
                              fi
                              # 重新计算分页信息
                              total_categories=${#filtered_categories[@]}
                              total_pages=$(( (total_categories + current_page_size - 1) / current_page_size ))
                              current_page=1
                              continue ;; 
                        [sS]) read -p "请输入每页显示数量: " new_size
                              if [ "$new_size" -gt 0 ] 2>/dev/null; then
                                  current_page_size=$new_size
                                  # 重新计算分页信息
                                  total_categories=${#filtered_categories[@]}
                                  total_pages=$(( (total_categories + current_page_size - 1) / current_page_size ))
                                  current_page=1
                              else
                                  echo -e "${RED}无效的数量，请输入大于0的数字${NC}"
                                  sleep 1
                              fi
                              continue ;; 
                        [nN]) if [ $current_page -lt $total_pages ]; then current_page=$((current_page + 1)); else echo -e "${YELLOW}已经是最后一页${NC}"; sleep 1; fi; continue ;; 
                        [pP]) if [ $current_page -gt 1 ]; then current_page=$((current_page - 1)); else echo -e "${YELLOW}已经是第一页${NC}"; sleep 1; fi; continue ;; 
                    esac
                    
                    # 处理数字选择
                    if [ "$choice" -ge 1 ] && [ "$choice" -le $total_categories ]; then
                        selected_category=${filtered_categories[$((choice-1))]}
                        show_categories=false
                        break
                    else
                        echo -e "${RED}无效选择，请重新输入${NC}"; sleep 1; continue
                    fi
                done
            else
                # 获取联系人列表
                contacts=($(get_yaml_files "$selected_category"))
                if [ ${#contacts[@]} -eq 0 ]; then
                    echo -e "${RED}该分类下没有联系人${NC}"
                    read -p "按 Enter 键返回..." -n 1
                    show_categories=true
                    continue
                fi
                
                # 分页显示联系人
                local original_contacts=(${contacts[@]})
                local filtered_contacts=(${original_contacts[@]})
                local search_query=""
                local total_contacts
                local total_pages
                local current_page
                total_contacts=${#filtered_contacts[@]}
                total_pages=$(( (total_contacts + current_page_size - 1) / current_page_size ))
                current_page=1
                
                while true; do
                    clear
                    echo -e "${BLUE}=====================================${NC}"
                    echo -e "${BLUE}          分类: $selected_category${NC}"
                    echo -e "${BLUE}=====================================${NC}"
                    echo -e "${YELLOW}【快捷操作】: m.返回主菜单 | b.返回分类列表 | q.退出程序 | f.搜索 | s.自定义每页显示数量 (当前: $current_page_size)${NC}"
                    
                    # 显示搜索状态
                    if [ -n "$search_query" ]; then
                        echo -e "${YELLOW}【搜索中】: '$search_query' (按 f 清空搜索)${NC}"
                    fi
                    
                    echo -e "${BLUE}-------------------------------------${NC}"
                    echo -e "${YELLOW}请选择联系人:${NC}"
                    echo -e "${YELLOW}第 $current_page/$total_pages 页，共 $total_contacts 个联系人${NC}"
                    echo -e "${BLUE}-------------------------------------${NC}"
                    
                    # 计算当前页的起始和结束索引
                    local start_idx=$(( (current_page - 1) * current_page_size ))
                    local end_idx=$(( start_idx + current_page_size - 1 ))
                    if [ $end_idx -ge $total_contacts ]; then
                        end_idx=$((total_contacts - 1))
                    fi
                    
                    # 显示当前页的联系人
                    for ((i=start_idx; i<=end_idx; i++)); do
                        echo -e "${YELLOW}$((i+1)). ${filtered_contacts[$i]}${NC}"
                    done
                    
                    # 显示分页导航
                    echo -e "${BLUE}-------------------------------------${NC}"
                    echo -e "${YELLOW}分页导航: p.上一页 | n.下一页${NC}"
                    
                    # 读取用户选择
                    read -p "请输入选择: " choice
                    
                    # 处理字母快捷操作
                    case "$choice" in
                        [mM]) show_main_menu; return ;; 
                        [bB]) show_categories=true
                              break ;; 
                        [qQ]) echo -e "${GREEN}谢谢使用！${NC}"; exit 0 ;; 
                        [fF]) # 处理搜索功能
                              read -p "请输入搜索关键词 (直接回车清空搜索): " search_query
                              if [ -n "$search_query" ]; then
                                  # 过滤联系人列表，支持模糊搜索
                                  filtered_contacts=()
                                  for contact in "${original_contacts[@]}"; do
                                      if echo "$contact" | grep -i "$search_query" >/dev/null 2>&1; then
                                          filtered_contacts+=($contact)
                                      fi
                                  done
                              else
                                  # 清空搜索，恢复原始列表
                                  filtered_contacts=(${original_contacts[@]})
                              fi
                              # 重新计算分页信息
                              total_contacts=${#filtered_contacts[@]}
                              total_pages=$(( (total_contacts + current_page_size - 1) / current_page_size ))
                              current_page=1
                              continue ;; 
                        [sS]) read -p "请输入每页显示数量: " new_size
                              if [ "$new_size" -gt 0 ] 2>/dev/null; then
                                  current_page_size=$new_size
                                  # 重新计算分页信息
                                  total_contacts=${#filtered_contacts[@]}
                                  total_pages=$(( (total_contacts + current_page_size - 1) / current_page_size ))
                                  current_page=1
                              else
                                  echo -e "${RED}无效的数量，请输入大于0的数字${NC}"
                                  sleep 1
                              fi
                              continue ;; 
                        [nN]) if [ $current_page -lt $total_pages ]; then current_page=$((current_page + 1)); else echo -e "${YELLOW}已经是最后一页${NC}"; sleep 1; fi; continue ;; 
                        [pP]) if [ $current_page -gt 1 ]; then current_page=$((current_page - 1)); else echo -e "${YELLOW}已经是第一页${NC}"; sleep 1; fi; continue ;; 
                    esac
                    
                    # 处理数字选择
                    if [ "$choice" -ge 1 ] && [ "$choice" -le $total_contacts ]; then
                        contact=${filtered_contacts[$((choice-1))]}
                        
                        # 显示联系人详情
                        clear
                        echo -e "${BLUE}=====================================${NC}"
                        echo -e "${BLUE}        联系人详情${NC}"
                        echo -e "${BLUE}=====================================${NC}"
                        
                        yaml_content=$(read_yaml "$selected_category" "$contact")
                        organization=$(get_yaml_field "$yaml_content" "organization")
                        cell_phone=$(get_yaml_field "$yaml_content" "cellPhone" | tr '\n' ', ' | sed 's/,$//')
                        url=$(get_yaml_field "$yaml_content" "url")
                        work_email=$(get_yaml_field "$yaml_content" "workEmail" | tr '\n' ', ' | sed 's/,$//')
                        
                        echo -e "${YELLOW}组织名称:${NC} $organization"
                        echo -e "${YELLOW}电话号码:${NC} ${cell_phone:-无}"
                        echo -e "${YELLOW}网址:${NC} ${url:-无}"
                        echo -e "${YELLOW}邮箱:${NC} ${work_email:-无}"
                        echo -e "${BLUE}=====================================${NC}"
                        
                        read -p "按 Enter 键返回..." -n 1
                        continue
                    else
                        echo -e "${RED}无效选择，请重新输入${NC}"; sleep 1; continue
                    fi
                done
            fi
        done
    fi
}

# 创建联系人
function create_contact() {
    clear
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}            创建联系人${NC}"
    echo -e "${BLUE}=====================================${NC}"
    
    # 顶部快捷操作栏
    echo -e "${YELLOW}【快捷操作】: m.返回主菜单 | q.退出程序 | c.取消${NC}"
    echo -e "${BLUE}-------------------------------------${NC}"
    
    # 获取分类列表
    categories=($(get_categories))
    if [ ${#categories[@]} -eq 0 ]; then
        echo -e "${RED}没有找到分类${NC}"
        read -p "按 Enter 键返回主菜单..." -n 1
        show_main_menu
        return
    fi
    
    # 选择分类
    while true; do
        # 分页显示分类
        local original_categories=(${categories[@]})
        local filtered_categories=(${original_categories[@]})
        local search_query=""
        local total_categories
        local total_pages
        local current_page
        total_categories=${#filtered_categories[@]}
        total_pages=$(( (total_categories + current_page_size - 1) / current_page_size ))
        current_page=1
        
        while true; do
            clear
            echo -e "${BLUE}=====================================${NC}"
            echo -e "${BLUE}            创建联系人${NC}"
            echo -e "${BLUE}=====================================${NC}"
            
            # 顶部快捷操作栏
            echo -e "${YELLOW}【快捷操作】: m.返回主菜单 | q.退出程序 | c.取消 | f.搜索 | s.自定义每页显示数量 (当前: $current_page_size)${NC}"
            
            # 显示搜索状态
            if [ -n "$search_query" ]; then
                echo -e "${YELLOW}【搜索中】: '$search_query' (按 f 清空搜索)${NC}"
            fi
            
            echo -e "${BLUE}-------------------------------------${NC}"
            echo -e "${YELLOW}请选择分类:${NC}"
            echo -e "${YELLOW}第 $current_page/$total_pages 页，共 $total_categories 个分类${NC}"
            echo -e "${BLUE}-------------------------------------${NC}"
            
            # 计算当前页的起始和结束索引
            local start_idx=$(( (current_page - 1) * current_page_size ))
            local end_idx=$(( start_idx + current_page_size - 1 ))
            if [ $end_idx -ge $total_categories ]; then
                end_idx=$((total_categories - 1))
            fi
            
            # 显示当前页的分类
            for ((i=start_idx; i<=end_idx; i++)); do
                echo -e "${YELLOW}$((i+1)). ${filtered_categories[$i]}${NC}"
            done
            
            # 显示分页导航
            echo -e "${BLUE}-------------------------------------${NC}"
            echo -e "${YELLOW}分页导航: p.上一页 | n.下一页${NC}"
            
            # 读取用户选择
            read -p "请输入选择: " category_choice
            
            # 处理字母快捷操作
            case "$category_choice" in
                [mM]) show_main_menu; return ;; 
                [qQ]) echo -e "${GREEN}谢谢使用！${NC}"; exit 0 ;; 
                [cC]) echo -e "${GREEN}已取消创建联系人${NC}"; sleep 1; show_main_menu; return ;; 
                [fF]) # 处理搜索功能
                      read -p "请输入搜索关键词 (直接回车清空搜索): " search_query
                      if [ -n "$search_query" ]; then
                          # 过滤分类列表，支持模糊搜索
                          filtered_categories=()
                          for category in "${original_categories[@]}"; do
                              if echo "$category" | grep -i "$search_query" >/dev/null 2>&1; then
                                  filtered_categories+=($category)
                              fi
                          done
                      else
                          # 清空搜索，恢复原始列表
                          filtered_categories=(${original_categories[@]})
                      fi
                      # 重新计算分页信息
                      total_categories=${#filtered_categories[@]}
                      total_pages=$(( (total_categories + current_page_size - 1) / current_page_size ))
                      current_page=1
                      continue ;; 
                [sS]) read -p "请输入每页显示数量: " new_size
                      if [ "$new_size" -gt 0 ] 2>/dev/null; then
                          current_page_size=$new_size
                          # 重新计算分页信息
                          total_categories=${#filtered_categories[@]}
                          total_pages=$(( (total_categories + current_page_size - 1) / current_page_size ))
                          current_page=1
                      else
                          echo -e "${RED}无效的数量，请输入大于0的数字${NC}"
                          sleep 1
                      fi
                      continue ;; 
                [nN]) if [ $current_page -lt $total_pages ]; then current_page=$((current_page + 1)); else echo -e "${YELLOW}已经是最后一页${NC}"; sleep 1; fi; continue ;; 
                [pP]) if [ $current_page -gt 1 ]; then current_page=$((current_page - 1)); else echo -e "${YELLOW}已经是第一页${NC}"; sleep 1; fi; continue ;; 
            esac
            
            # 处理数字选择
            if [ "$category_choice" -ge 1 ] && [ "$category_choice" -le $total_categories ]; then
                category=${filtered_categories[$((category_choice-1))]}
                break 2
            else
                echo -e "${RED}无效选择，请重新输入${NC}"; sleep 1; continue
            fi
        done
    done
    
    # 输入联系人信息
    read -p "请输入组织名称 (c.取消): " organization
    if [ "$organization" = "c" ] || [ "$organization" = "C" ]; then
        echo -e "${GREEN}已取消创建联系人${NC}"
        sleep 1
        show_main_menu
        return
    fi
    
    read -p "请输入电话号码 (多个号码用空格分隔，c.取消): " cell_phone
    if [ "$cell_phone" = "c" ] || [ "$cell_phone" = "C" ]; then
        echo -e "${GREEN}已取消创建联系人${NC}"
        sleep 1
        show_main_menu
        return
    fi
    
    read -p "请输入网址 (c.取消): " url
    if [ "$url" = "c" ] || [ "$url" = "C" ]; then
        echo -e "${GREEN}已取消创建联系人${NC}"
        sleep 1
        show_main_menu
        return
    fi
    
    read -p "请输入邮箱 (多个邮箱用空格分隔，c.取消): " work_email
    if [ "$work_email" = "c" ] || [ "$work_email" = "C" ]; then
        echo -e "${GREEN}已取消创建联系人${NC}"
        sleep 1
        show_main_menu
        return
    fi
    
    # 确认保存
    echo -e "${BLUE}-------------------------------------${NC}"
    echo -e "${YELLOW}确认创建联系人吗？${NC}"
    echo -e "${YELLOW}组织名称:${NC} $organization"
    echo -e "${YELLOW}电话号码:${NC} ${cell_phone:-无}"
    echo -e "${YELLOW}网址:${NC} ${url:-无}"
    echo -e "${YELLOW}邮箱:${NC} ${work_email:-无}"
    echo -e "${BLUE}-------------------------------------${NC}"
    read -p "请输入选择 (y.确认保存 | c.取消): " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        # 生成 YAML 内容
        yaml_content=$(generate_yaml "$organization" "$cell_phone" "$url" "$work_email")
        
        # 保存文件
        save_yaml "$category" "$organization" "$yaml_content"
    else
        echo -e "${GREEN}已取消创建联系人${NC}"
    fi
    
    read -p "按 Enter 键返回主菜单..." -n 1
    show_main_menu
}

# 编辑联系人
function edit_contact() {
    clear
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}            编辑联系人${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${YELLOW}1. 按分类编辑${NC}"
    echo -e "${YELLOW}2. 直接搜索所有联系人进行编辑${NC}"
    echo -e "${BLUE}-------------------------------------${NC}"
    echo -e "${YELLOW}【快捷操作】: m.返回主菜单 | q.退出程序${NC}"
    echo -e "${BLUE}-------------------------------------${NC}"
    
    read -p "请输入选择: " choice
    
    case $choice in
        [mM]) show_main_menu; return ;; 
        [qQ]) echo -e "${GREEN}谢谢使用！${NC}"; exit 0 ;; 
        1) edit_by_category=true ;; 
        2) direct_edit=true ;; 
        *) echo -e "${RED}无效选择，请重新输入${NC}"; sleep 1; edit_contact; return ;; 
    esac
    
    if [ "$direct_edit" = true ]; then
        # 直接搜索所有联系人
        local all_contacts=($(get_all_contacts))
        if [ ${#all_contacts[@]} -eq 0 ]; then
            echo -e "${RED}没有找到联系人${NC}"
            read -p "按 Enter 键返回主菜单..." -n 1
            show_main_menu
            return
        fi
        
        # 分页显示所有联系人
        local original_contacts=(${all_contacts[@]})
        local filtered_contacts=(${original_contacts[@]})
        local search_query=""
        local total_contacts
        local total_pages
        local current_page
        total_contacts=${#filtered_contacts[@]}
        total_pages=$(( (total_contacts + current_page_size - 1) / current_page_size ))
        current_page=1
        
        while true; do
            clear
            echo -e "${BLUE}=====================================${NC}"
            echo -e "${BLUE}        直接搜索编辑联系人${NC}"
            echo -e "${BLUE}=====================================${NC}"
            echo -e "${YELLOW}【快捷操作】: m.返回主菜单 | q.退出程序 | f.搜索 | s.自定义每页显示数量 (当前: $current_page_size)${NC}"
            
            # 显示搜索状态
            if [ -n "$search_query" ]; then
                echo -e "${YELLOW}【搜索中】: '$search_query' (按 f 清空搜索)${NC}"
            fi
            
            echo -e "${BLUE}-------------------------------------${NC}"
            echo -e "${YELLOW}请选择联系人:${NC}"
            echo -e "${YELLOW}第 $current_page/$total_pages 页，共 $total_contacts 个联系人${NC}"
            echo -e "${BLUE}-------------------------------------${NC}"
            
            # 计算当前页的起始和结束索引
            local start_idx=$(( (current_page - 1) * current_page_size ))
            local end_idx=$(( start_idx + current_page_size - 1 ))
            if [ $end_idx -ge $total_contacts ]; then
                end_idx=$((total_contacts - 1))
            fi
            
            # 显示当前页的联系人
            for ((i=start_idx; i<=end_idx; i++)); do
                # 显示格式为 "分类:联系人"，但只显示联系人名称
                local contact_info=${filtered_contacts[$i]}
                local contact_name=${contact_info#*:}
                echo -e "${YELLOW}$((i+1)). ${contact_name}${NC}"
            done
            
            # 显示分页导航
            echo -e "${BLUE}-------------------------------------${NC}"
            echo -e "${YELLOW}分页导航: p.上一页 | n.下一页${NC}"
            
            # 读取用户选择
            read -p "请输入选择: " choice
            
            # 处理字母快捷操作
            case "$choice" in
                [mM]) show_main_menu; return ;; 
                [qQ]) echo -e "${GREEN}谢谢使用！${NC}"; exit 0 ;; 
                [fF]) # 处理搜索功能
                      read -p "请输入搜索关键词 (直接回车清空搜索): " search_query
                      if [ -n "$search_query" ]; then
                          # 过滤联系人列表，支持模糊搜索
                          filtered_contacts=()
                          for contact in "${original_contacts[@]}"; do
                              local contact_name=${contact#*:}
                              if echo "$contact_name" | grep -i "$search_query" >/dev/null 2>&1; then
                                  filtered_contacts+=($contact)
                              fi
                          done
                      else
                          # 清空搜索，恢复原始列表
                          filtered_contacts=(${original_contacts[@]})
                      fi
                      # 重新计算分页信息
                      total_contacts=${#filtered_contacts[@]}
                      total_pages=$(( (total_contacts + current_page_size - 1) / current_page_size ))
                      current_page=1
                      continue ;; 
                [sS]) read -p "请输入每页显示数量: " new_size
                      if [ "$new_size" -gt 0 ] 2>/dev/null; then
                          current_page_size=$new_size
                          # 重新计算分页信息
                          total_contacts=${#filtered_contacts[@]}
                          total_pages=$(( (total_contacts + current_page_size - 1) / current_page_size ))
                          current_page=1
                      else
                          echo -e "${RED}无效的数量，请输入大于0的数字${NC}"
                          sleep 1
                      fi
                      continue ;; 
                [nN]) if [ $current_page -lt $total_pages ]; then current_page=$((current_page + 1)); else echo -e "${YELLOW}已经是最后一页${NC}"; sleep 1; fi; continue ;; 
                [pP]) if [ $current_page -gt 1 ]; then current_page=$((current_page - 1)); else echo -e "${YELLOW}已经是第一页${NC}"; sleep 1; fi; continue ;; 
            esac
            
            # 处理数字选择
            if [ "$choice" -ge 1 ] && [ "$choice" -le $total_contacts ]; then
                local contact_info=${filtered_contacts[$((choice-1))]}
                local category=${contact_info%%:*}
                local contact=${contact_info#*:}
                
                # 读取当前联系人信息
                yaml_content=$(read_yaml "$category" "$contact")
                
                # 解析当前字段值 - 保留原始换行格式
                current_organization=$(get_yaml_field "$yaml_content" "organization")
                # 保留换行格式的正确方式
                current_cell_phone="$(get_yaml_field "$yaml_content" "cellPhone")"
                current_url=$(get_yaml_field "$yaml_content" "url")
                # 保留换行格式的正确方式
                current_work_email="$(get_yaml_field "$yaml_content" "workEmail")"
                
                # 输入新的联系人信息，支持默认值
                read -p "请输入组织名称 [$current_organization] (c.取消): " organization
                if [ "$organization" = "c" ] || [ "$organization" = "C" ]; then
                    echo -e "${GREEN}已取消编辑联系人${NC}"
                    sleep 1
                    show_main_menu
                    return
                fi
                organization=${organization:-$current_organization}
                
                # 编辑电话号码（数组字段）
                echo -e "${BLUE}-------------------------------------${NC}"
                echo -e "${YELLOW}编辑电话号码${NC}"
                edited_phone=$(edit_array_field "电话号码" "$current_cell_phone")
                if [ $? -eq 0 ]; then
                    current_cell_phone="$edited_phone"
                fi
                
                # 编辑网址（非数组字段）
                read -p "请输入网址 [$current_url] (c.取消): " url
                if [ "$url" = "c" ] || [ "$url" = "C" ]; then
                    echo -e "${GREEN}已取消编辑联系人${NC}"
                    sleep 1
                    show_main_menu
                    return
                fi
                url=${url:-$current_url}
                
                # 编辑邮箱（数组字段）
                echo -e "${BLUE}-------------------------------------${NC}"
                echo -e "${YELLOW}编辑邮箱${NC}"
                edited_email=$(edit_array_field "邮箱" "$current_work_email")
                if [ $? -eq 0 ]; then
                    current_work_email="$edited_email"
                fi
                
                # 确认保存
                # 转换电话号码和邮箱格式为逗号分隔，便于显示
                local display_phone=$(echo "$current_cell_phone" | tr '\n' ', ' | sed 's/,$//')
                local display_email=$(echo "$current_work_email" | tr '\n' ', ' | sed 's/,$//')
                
                echo -e "${BLUE}-------------------------------------${NC}"
                echo -e "${YELLOW}确认保存联系人修改吗？${NC}"
                echo -e "${YELLOW}组织名称:${NC} $organization"
                echo -e "${YELLOW}电话号码:${NC} ${display_phone:-无}"
                echo -e "${YELLOW}网址:${NC} ${url:-无}"
                echo -e "${YELLOW}邮箱:${NC} ${display_email:-无}"
                echo -e "${BLUE}-------------------------------------${NC}"
                read -p "请输入选择 (y.确认保存 | c.取消): " confirm
                
                if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                    # 生成 YAML 内容
                    yaml_content=$(generate_yaml "$organization" "$current_cell_phone" "$url" "$current_work_email")
                    
                    # 保存文件
                    save_yaml "$category" "$contact" "$yaml_content"
                else
                    echo -e "${GREEN}已取消编辑联系人${NC}"
                fi
                
                read -p "按 Enter 键返回主菜单..." -n 1
                show_main_menu
                return
            else
                echo -e "${RED}无效选择，请重新输入${NC}"; sleep 1; continue
            fi
        done
    else
        # 按分类编辑联系人
        # 获取分类列表
        categories=($(get_categories))
        if [ ${#categories[@]} -eq 0 ]; then
            echo -e "${RED}没有找到分类${NC}"
            read -p "按 Enter 键返回主菜单..." -n 1
            show_main_menu
            return
        fi
        
        # 选择分类
        while true; do
            # 分页显示分类
            local original_categories=(${categories[@]})
            local filtered_categories=(${original_categories[@]})
            local search_query=""
            local total_categories
            local total_pages
            local current_page
            total_categories=${#filtered_categories[@]}
            total_pages=$(( (total_categories + current_page_size - 1) / current_page_size ))
            current_page=1
            
            while true; do
                clear
                echo -e "${BLUE}=====================================${NC}"
                echo -e "${BLUE}            编辑联系人${NC}"
                echo -e "${BLUE}=====================================${NC}"
                
                # 顶部快捷操作栏
                echo -e "${YELLOW}【快捷操作】: m.返回主菜单 | q.退出程序 | c.取消 | f.搜索 | s.自定义每页显示数量 (当前: $current_page_size)${NC}"
                
                # 显示搜索状态
                if [ -n "$search_query" ]; then
                    echo -e "${YELLOW}【搜索中】: '$search_query' (按 f 清空搜索)${NC}"
                fi
                
                echo -e "${BLUE}-------------------------------------${NC}"
                echo -e "${YELLOW}请选择分类:${NC}"
                echo -e "${YELLOW}第 $current_page/$total_pages 页，共 $total_categories 个分类${NC}"
                echo -e "${BLUE}-------------------------------------${NC}"
                
                # 计算当前页的起始和结束索引
                local start_idx=$(( (current_page - 1) * current_page_size ))
                local end_idx=$(( start_idx + current_page_size - 1 ))
                if [ $end_idx -ge $total_categories ]; then
                    end_idx=$((total_categories - 1))
                fi
                
                # 显示当前页的分类
                for ((i=start_idx; i<=end_idx; i++)); do
                    echo -e "${YELLOW}$((i+1)). ${filtered_categories[$i]}${NC}"
                done
                
                # 显示分页导航
                echo -e "${BLUE}-------------------------------------${NC}"
                echo -e "${YELLOW}分页导航: p.上一页 | n.下一页${NC}"
                
                # 读取用户选择
                read -p "请输入选择: " category_choice
                
                # 处理字母快捷操作
                case "$category_choice" in
                    [mM]) show_main_menu; return ;; 
                    [qQ]) echo -e "${GREEN}谢谢使用！${NC}"; exit 0 ;; 
                    [cC]) echo -e "${GREEN}已取消编辑联系人${NC}"; sleep 1; show_main_menu; return ;; 
                    [fF]) # 处理搜索功能
                          read -p "请输入搜索关键词 (直接回车清空搜索): " search_query
                          if [ -n "$search_query" ]; then
                              # 过滤分类列表，支持模糊搜索
                              filtered_categories=()
                              for category in "${original_categories[@]}"; do
                                  if echo "$category" | grep -i "$search_query" >/dev/null 2>&1; then
                                      filtered_categories+=($category)
                                  fi
                              done
                          else
                              # 清空搜索，恢复原始列表
                              filtered_categories=(${original_categories[@]})
                          fi
                          # 重新计算分页信息
                          total_categories=${#filtered_categories[@]}
                          total_pages=$(( (total_categories + current_page_size - 1) / current_page_size ))
                          current_page=1
                          continue ;; 
                    [sS]) read -p "请输入每页显示数量: " new_size
                          if [ "$new_size" -gt 0 ] 2>/dev/null; then
                              current_page_size=$new_size
                              # 重新计算分页信息
                              total_categories=${#filtered_categories[@]}
                              total_pages=$(( (total_categories + current_page_size - 1) / current_page_size ))
                              current_page=1
                          else
                              echo -e "${RED}无效的数量，请输入大于0的数字${NC}"
                              sleep 1
                          fi
                          continue ;; 
                    [nN]) if [ $current_page -lt $total_pages ]; then current_page=$((current_page + 1)); else echo -e "${YELLOW}已经是最后一页${NC}"; sleep 1; fi; continue ;; 
                    [pP]) if [ $current_page -gt 1 ]; then current_page=$((current_page - 1)); else echo -e "${YELLOW}已经是第一页${NC}"; sleep 1; fi; continue ;; 
                esac
                
                # 处理数字选择
                if [ "$category_choice" -ge 1 ] && [ "$category_choice" -le $total_categories ]; then
                    category=${filtered_categories[$((category_choice-1))]}
                    break 2
                else
                    echo -e "${RED}无效选择，请重新输入${NC}"; sleep 1; continue
                fi
            done
        done
        
        # 获取联系人列表
        contacts=($(get_yaml_files "$category"))
        if [ ${#contacts[@]} -eq 0 ]; then
            echo -e "${RED}该分类下没有联系人${NC}"
            read -p "按 Enter 键返回主菜单..." -n 1
            show_main_menu
            return
        fi
        
        # 选择联系人
        while true; do
            # 分页显示联系人
            local original_contacts=(${contacts[@]})
            local filtered_contacts=(${original_contacts[@]})
            local search_query=""
            local total_contacts
            local total_pages
            local current_page
            total_contacts=${#filtered_contacts[@]}
            total_pages=$(( (total_contacts + current_page_size - 1) / current_page_size ))
            current_page=1
            
            while true; do
                clear
                echo -e "${BLUE}=====================================${NC}"
                echo -e "${BLUE}            编辑联系人${NC}"
                echo -e "${BLUE}          分类: $category${NC}"
                echo -e "${BLUE}=====================================${NC}"
                
                # 顶部快捷操作栏
                echo -e "${YELLOW}【快捷操作】: m.返回主菜单 | q.退出程序 | c.取消 | f.搜索 | s.自定义每页显示数量 (当前: $current_page_size)${NC}"
                
                # 显示搜索状态
                if [ -n "$search_query" ]; then
                    echo -e "${YELLOW}【搜索中】: '$search_query' (按 f 清空搜索)${NC}"
                fi
                
                echo -e "${BLUE}-------------------------------------${NC}"
                echo -e "${YELLOW}请选择联系人:${NC}"
                echo -e "${YELLOW}第 $current_page/$total_pages 页，共 $total_contacts 个联系人${NC}"
                echo -e "${BLUE}-------------------------------------${NC}"
                
                # 计算当前页的起始和结束索引
                local start_idx=$(( (current_page - 1) * current_page_size ))
                local end_idx=$(( start_idx + current_page_size - 1 ))
                if [ $end_idx -ge $total_contacts ]; then
                    end_idx=$((total_contacts - 1))
                fi
                
                # 显示当前页的联系人
                for ((i=start_idx; i<=end_idx; i++)); do
                    echo -e "${YELLOW}$((i+1)). ${filtered_contacts[$i]}${NC}"
                done
                
                # 显示分页导航
                echo -e "${BLUE}-------------------------------------${NC}"
                echo -e "${YELLOW}分页导航: p.上一页 | n.下一页${NC}"
                
                # 读取用户选择
                read -p "请输入选择: " contact_choice
                
                # 处理字母快捷操作
                case "$contact_choice" in
                    [mM]) show_main_menu; return ;; 
                    [qQ]) echo -e "${GREEN}谢谢使用！${NC}"; exit 0 ;; 
                    [cC]) echo -e "${GREEN}已取消编辑联系人${NC}"; sleep 1; show_main_menu; return ;; 
                    [fF]) # 处理搜索功能
                          read -p "请输入搜索关键词 (直接回车清空搜索): " search_query
                          if [ -n "$search_query" ]; then
                              # 过滤联系人列表，支持模糊搜索
                              filtered_contacts=()
                              for contact in "${original_contacts[@]}"; do
                                  if echo "$contact" | grep -i "$search_query" >/dev/null 2>&1; then
                                      filtered_contacts+=($contact)
                                  fi
                              done
                          else
                              # 清空搜索，恢复原始列表
                              filtered_contacts=(${original_contacts[@]})
                          fi
                          # 重新计算分页信息
                          total_contacts=${#filtered_contacts[@]}
                          total_pages=$(( (total_contacts + current_page_size - 1) / current_page_size ))
                          current_page=1
                          continue ;; 
                    [sS]) read -p "请输入每页显示数量: " new_size
                          if [ "$new_size" -gt 0 ] 2>/dev/null; then
                              current_page_size=$new_size
                              # 重新计算分页信息
                              total_contacts=${#filtered_contacts[@]}
                              total_pages=$(( (total_contacts + current_page_size - 1) / current_page_size ))
                              current_page=1
                          else
                              echo -e "${RED}无效的数量，请输入大于0的数字${NC}"
                              sleep 1
                          fi
                          continue ;; 
                    [nN]) if [ $current_page -lt $total_pages ]; then current_page=$((current_page + 1)); else echo -e "${YELLOW}已经是最后一页${NC}"; sleep 1; fi; continue ;; 
                    [pP]) if [ $current_page -gt 1 ]; then current_page=$((current_page - 1)); else echo -e "${YELLOW}已经是第一页${NC}"; sleep 1; fi; continue ;; 
                esac
                
                # 处理数字选择
                if [ "$contact_choice" -ge 1 ] && [ "$contact_choice" -le $total_contacts ]; then
                    contact=${filtered_contacts[$((contact_choice-1))]}
                    break 2
                else
                    echo -e "${RED}无效选择，请重新输入${NC}"; sleep 1; continue
                fi
            done
        done
        
        # 读取当前联系人信息
        yaml_content=$(read_yaml "$category" "$contact")
        
        # 解析当前字段值 - 保留原始换行格式
        current_organization=$(get_yaml_field "$yaml_content" "organization")
        # 保留换行格式的正确方式
        current_cell_phone="$(get_yaml_field "$yaml_content" "cellPhone")"
        current_url=$(get_yaml_field "$yaml_content" "url")
        # 保留换行格式的正确方式
        current_work_email="$(get_yaml_field "$yaml_content" "workEmail")"
        
        # 输入新的联系人信息，支持默认值
        read -p "请输入组织名称 [$current_organization] (c.取消): " organization
        if [ "$organization" = "c" ] || [ "$organization" = "C" ]; then
            echo -e "${GREEN}已取消编辑联系人${NC}"
            sleep 1
            show_main_menu
            return
        fi
        organization=${organization:-$current_organization}
        
        # 编辑电话号码（数组字段）
        echo -e "${BLUE}-------------------------------------${NC}"
        echo -e "${YELLOW}编辑电话号码${NC}"
        edited_phone=$(edit_array_field "电话号码" "$current_cell_phone")
        if [ $? -eq 0 ]; then
            current_cell_phone="$edited_phone"
        fi
        
        # 编辑网址（非数组字段）
        read -p "请输入网址 [$current_url] (c.取消): " url
        if [ "$url" = "c" ] || [ "$url" = "C" ]; then
            echo -e "${GREEN}已取消编辑联系人${NC}"
            sleep 1
            show_main_menu
            return
        fi
        url=${url:-$current_url}
        
        # 编辑邮箱（数组字段）
        echo -e "${BLUE}-------------------------------------${NC}"
        echo -e "${YELLOW}编辑邮箱${NC}"
        edited_email=$(edit_array_field "邮箱" "$current_work_email")
        if [ $? -eq 0 ]; then
            current_work_email="$edited_email"
        fi
        
        # 确认保存
        # 转换电话号码和邮箱格式为逗号分隔，便于显示
        local display_phone=$(echo "$current_cell_phone" | tr '\n' ', ' | sed 's/,$//')
        local display_email=$(echo "$current_work_email" | tr '\n' ', ' | sed 's/,$//')
        
        echo -e "${BLUE}-------------------------------------${NC}"
        echo -e "${YELLOW}确认保存联系人修改吗？${NC}"
        echo -e "${YELLOW}组织名称:${NC} $organization"
        echo -e "${YELLOW}电话号码:${NC} ${display_phone:-无}"
        echo -e "${YELLOW}网址:${NC} ${url:-无}"
        echo -e "${YELLOW}邮箱:${NC} ${display_email:-无}"
        echo -e "${BLUE}-------------------------------------${NC}"
        read -p "请输入选择 (y.确认保存 | c.取消): " confirm
        
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            # 生成 YAML 内容
            yaml_content=$(generate_yaml "$organization" "$current_cell_phone" "$url" "$current_work_email")
            
            # 保存文件
            save_yaml "$category" "$contact" "$yaml_content"
        else
            echo -e "${GREEN}已取消编辑联系人${NC}"
        fi
        
        read -p "按 Enter 键返回主菜单..." -n 1
        show_main_menu
    fi
}

# 删除联系人
function delete_contact() {
    clear
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}            删除联系人${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${YELLOW}1. 按分类删除${NC}"
    echo -e "${YELLOW}2. 直接搜索所有联系人进行删除${NC}"
    echo -e "${BLUE}-------------------------------------${NC}"
    echo -e "${YELLOW}【快捷操作】: m.返回主菜单 | q.退出程序${NC}"
    echo -e "${BLUE}-------------------------------------${NC}"
    
    read -p "请输入选择: " choice
    
    case $choice in
        [mM]) show_main_menu; return ;; 
        [qQ]) echo -e "${GREEN}谢谢使用！${NC}"; exit 0 ;; 
        1) delete_by_category=true ;; 
        2) direct_delete=true ;; 
        *) echo -e "${RED}无效选择，请重新输入${NC}"; sleep 1; delete_contact; return ;; 
    esac
    
    if [ "$direct_delete" = true ]; then
        # 直接搜索所有联系人
        local all_contacts=($(get_all_contacts))
        if [ ${#all_contacts[@]} -eq 0 ]; then
            echo -e "${RED}没有找到联系人${NC}"
            read -p "按 Enter 键返回主菜单..." -n 1
            show_main_menu
            return
        fi
        
        # 分页显示所有联系人
        local original_contacts=(${all_contacts[@]})
        local filtered_contacts=(${original_contacts[@]})
        local search_query=""
        local total_contacts
        local total_pages
        local current_page
        total_contacts=${#filtered_contacts[@]}
        total_pages=$(( (total_contacts + current_page_size - 1) / current_page_size ))
        current_page=1
        
        while true; do
            clear
            echo -e "${BLUE}=====================================${NC}"
            echo -e "${BLUE}        直接搜索删除联系人${NC}"
            echo -e "${BLUE}=====================================${NC}"
            echo -e "${YELLOW}【快捷操作】: m.返回主菜单 | q.退出程序 | f.搜索 | s.自定义每页显示数量 (当前: $current_page_size)${NC}"
            
            # 显示搜索状态
            if [ -n "$search_query" ]; then
                echo -e "${YELLOW}【搜索中】: '$search_query' (按 f 清空搜索)${NC}"
            fi
            
            echo -e "${BLUE}-------------------------------------${NC}"
            echo -e "${YELLOW}请选择联系人:${NC}"
            echo -e "${YELLOW}第 $current_page/$total_pages 页，共 $total_contacts 个联系人${NC}"
            echo -e "${BLUE}-------------------------------------${NC}"
            
            # 计算当前页的起始和结束索引
            local start_idx=$(( (current_page - 1) * current_page_size ))
            local end_idx=$(( start_idx + current_page_size - 1 ))
            if [ $end_idx -ge $total_contacts ]; then
                end_idx=$((total_contacts - 1))
            fi
            
            # 显示当前页的联系人
            for ((i=start_idx; i<=end_idx; i++)); do
                # 显示格式为 "分类:联系人"，但只显示联系人名称
                local contact_info=${filtered_contacts[$i]}
                local contact_name=${contact_info#*:}
                echo -e "${YELLOW}$((i+1)). ${contact_name}${NC}"
            done
            
            # 显示分页导航
            echo -e "${BLUE}-------------------------------------${NC}"
            echo -e "${YELLOW}分页导航: p.上一页 | n.下一页${NC}"
            
            # 读取用户选择
            read -p "请输入选择: " choice
            
            # 处理字母快捷操作
            case "$choice" in
                [mM]) show_main_menu; return ;; 
                [qQ]) echo -e "${GREEN}谢谢使用！${NC}"; exit 0 ;; 
                [fF]) # 处理搜索功能
                      read -p "请输入搜索关键词 (直接回车清空搜索): " search_query
                      if [ -n "$search_query" ]; then
                          # 过滤联系人列表，支持模糊搜索
                          filtered_contacts=()
                          for contact in "${original_contacts[@]}"; do
                              local contact_name=${contact#*:}
                              if echo "$contact_name" | grep -i "$search_query" >/dev/null 2>&1; then
                                  filtered_contacts+=($contact)
                              fi
                          done
                      else
                          # 清空搜索，恢复原始列表
                          filtered_contacts=(${original_contacts[@]})
                      fi
                      # 重新计算分页信息
                      total_contacts=${#filtered_contacts[@]}
                      total_pages=$(( (total_contacts + current_page_size - 1) / current_page_size ))
                      current_page=1
                      continue ;; 
                [sS]) read -p "请输入每页显示数量: " new_size
                      if [ "$new_size" -gt 0 ] 2>/dev/null; then
                          current_page_size=$new_size
                          # 重新计算分页信息
                          total_contacts=${#filtered_contacts[@]}
                          total_pages=$(( (total_contacts + current_page_size - 1) / current_page_size ))
                          current_page=1
                      else
                          echo -e "${RED}无效的数量，请输入大于0的数字${NC}"
                          sleep 1
                      fi
                      continue ;; 
                [nN]) if [ $current_page -lt $total_pages ]; then current_page=$((current_page + 1)); else echo -e "${YELLOW}已经是最后一页${NC}"; sleep 1; fi; continue ;; 
                [pP]) if [ $current_page -gt 1 ]; then current_page=$((current_page - 1)); else echo -e "${YELLOW}已经是第一页${NC}"; sleep 1; fi; continue ;; 
            esac
            
            # 处理数字选择
            if [ "$choice" -ge 1 ] && [ "$choice" -le $total_contacts ]; then
                local contact_info=${filtered_contacts[$((choice-1))]}
                local category=${contact_info%%:*}
                local contact=${contact_info#*:}
                
                # 确认删除
                read -p "确定要删除联系人 '$contact' 吗？(y/n): " confirm
                
                if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                    delete_yaml "$category" "$contact"
                fi
                
                read -p "按 Enter 键返回主菜单..." -n 1
                show_main_menu
                return
            else
                echo -e "${RED}无效选择，请重新输入${NC}"; sleep 1; continue
            fi
        done
    else
        # 按分类删除联系人
        # 获取分类列表
        categories=($(get_categories))
        if [ ${#categories[@]} -eq 0 ]; then
            echo -e "${RED}没有找到分类${NC}"
            read -p "按 Enter 键返回主菜单..." -n 1
            show_main_menu
            return
        fi
        
        # 选择分类
        while true; do
            # 分页显示分类
            local original_categories=(${categories[@]})
            local filtered_categories=(${original_categories[@]})
            local search_query=""
            local total_categories
            local total_pages
            local current_page
            total_categories=${#filtered_categories[@]}
            total_pages=$(( (total_categories + current_page_size - 1) / current_page_size ))
            current_page=1
            
            while true; do
                clear
                echo -e "${BLUE}=====================================${NC}"
                echo -e "${BLUE}            删除联系人${NC}"
                echo -e "${BLUE}=====================================${NC}"
                
                # 顶部快捷操作栏
                echo -e "${YELLOW}【快捷操作】: m.返回主菜单 | q.退出程序 | f.搜索 | s.自定义每页显示数量 (当前: $current_page_size)${NC}"
                
                # 显示搜索状态
                if [ -n "$search_query" ]; then
                    echo -e "${YELLOW}【搜索中】: '$search_query' (按 f 清空搜索)${NC}"
                fi
                
                echo -e "${BLUE}-------------------------------------${NC}"
                echo -e "${YELLOW}请选择分类:${NC}"
                echo -e "${YELLOW}第 $current_page/$total_pages 页，共 $total_categories 个分类${NC}"
                echo -e "${BLUE}-------------------------------------${NC}"
                
                # 计算当前页的起始和结束索引
                local start_idx=$(( (current_page - 1) * current_page_size ))
                local end_idx=$(( start_idx + current_page_size - 1 ))
                if [ $end_idx -ge $total_categories ]; then
                    end_idx=$((total_categories - 1))
                fi
                
                # 显示当前页的分类
                for ((i=start_idx; i<=end_idx; i++)); do
                    echo -e "${YELLOW}$((i+1)). ${filtered_categories[$i]}${NC}"
                done
                
                # 显示分页导航
                echo -e "${BLUE}-------------------------------------${NC}"
                echo -e "${YELLOW}分页导航: p.上一页 | n.下一页${NC}"
                
                # 读取用户选择
                read -p "请输入选择: " category_choice
                
                # 处理字母快捷操作
                case "$category_choice" in
                    [mM]) show_main_menu; return ;; 
                    [qQ]) echo -e "${GREEN}谢谢使用！${NC}"; exit 0 ;; 
                    [fF]) # 处理搜索功能
                          read -p "请输入搜索关键词 (直接回车清空搜索): " search_query
                          if [ -n "$search_query" ]; then
                              # 过滤分类列表，支持模糊搜索
                              filtered_categories=()
                              for category in "${original_categories[@]}"; do
                                  if echo "$category" | grep -i "$search_query" >/dev/null 2>&1; then
                                      filtered_categories+=($category)
                                  fi
                              done
                          else
                              # 清空搜索，恢复原始列表
                              filtered_categories=(${original_categories[@]})
                          fi
                          # 重新计算分页信息
                          total_categories=${#filtered_categories[@]}
                          total_pages=$(( (total_categories + current_page_size - 1) / current_page_size ))
                          current_page=1
                          continue ;; 
                    [sS]) read -p "请输入每页显示数量: " new_size
                          if [ "$new_size" -gt 0 ] 2>/dev/null; then
                              current_page_size=$new_size
                              # 重新计算分页信息
                              total_categories=${#filtered_categories[@]}
                              total_pages=$(( (total_categories + current_page_size - 1) / current_page_size ))
                              current_page=1
                          else
                              echo -e "${RED}无效的数量，请输入大于0的数字${NC}"
                              sleep 1
                          fi
                          continue ;; 
                    [nN]) if [ $current_page -lt $total_pages ]; then current_page=$((current_page + 1)); else echo -e "${YELLOW}已经是最后一页${NC}"; sleep 1; fi; continue ;; 
                    [pP]) if [ $current_page -gt 1 ]; then current_page=$((current_page - 1)); else echo -e "${YELLOW}已经是第一页${NC}"; sleep 1; fi; continue ;; 
                esac
                
                # 处理数字选择
                if [ "$category_choice" -ge 1 ] && [ "$category_choice" -le $total_categories ]; then
                    category=${filtered_categories[$((category_choice-1))]}
                    break 2
                else
                    echo -e "${RED}无效选择，请重新输入${NC}"; sleep 1; continue
                fi
            done
        done
        
        # 获取联系人列表
        contacts=($(get_yaml_files "$category"))
        if [ ${#contacts[@]} -eq 0 ]; then
            echo -e "${RED}该分类下没有联系人${NC}"
            read -p "按 Enter 键返回主菜单..." -n 1
            show_main_menu
            return
        fi
        
        # 选择联系人
        while true; do
            # 分页显示联系人
            local original_contacts=(${contacts[@]})
            local filtered_contacts=(${original_contacts[@]})
            local search_query=""
            local total_contacts
            local total_pages
            local current_page
            total_contacts=${#filtered_contacts[@]}
            total_pages=$(( (total_contacts + current_page_size - 1) / current_page_size ))
            current_page=1
            
            while true; do
                clear
                echo -e "${BLUE}=====================================${NC}"
                echo -e "${BLUE}            删除联系人${NC}"
                echo -e "${BLUE}          分类: $category${NC}"
                echo -e "${BLUE}=====================================${NC}"
                
                # 顶部快捷操作栏
                echo -e "${YELLOW}【快捷操作】: m.返回主菜单 | q.退出程序 | f.搜索 | s.自定义每页显示数量 (当前: $current_page_size)${NC}"
                
                # 显示搜索状态
                if [ -n "$search_query" ]; then
                    echo -e "${YELLOW}【搜索中】: '$search_query' (按 f 清空搜索)${NC}"
                fi
                
                echo -e "${BLUE}-------------------------------------${NC}"
                echo -e "${YELLOW}请选择联系人:${NC}"
                echo -e "${YELLOW}第 $current_page/$total_pages 页，共 $total_contacts 个联系人${NC}"
                echo -e "${BLUE}-------------------------------------${NC}"
                
                # 计算当前页的起始和结束索引
                local start_idx=$(( (current_page - 1) * current_page_size ))
                local end_idx=$(( start_idx + current_page_size - 1 ))
                if [ $end_idx -ge $total_contacts ]; then
                    end_idx=$((total_contacts - 1))
                fi
                
                # 显示当前页的联系人
                for ((i=start_idx; i<=end_idx; i++)); do
                    echo -e "${YELLOW}$((i+1)). ${filtered_contacts[$i]}${NC}"
                done
                
                # 显示分页导航
                echo -e "${BLUE}-------------------------------------${NC}"
                echo -e "${YELLOW}分页导航: p.上一页 | n.下一页${NC}"
                
                # 读取用户选择
                read -p "请输入选择: " contact_choice
                
                # 处理字母快捷操作
                case "$contact_choice" in
                    [mM]) show_main_menu; return ;; 
                    [qQ]) echo -e "${GREEN}谢谢使用！${NC}"; exit 0 ;; 
                    [fF]) # 处理搜索功能
                          read -p "请输入搜索关键词 (直接回车清空搜索): " search_query
                          if [ -n "$search_query" ]; then
                              # 过滤联系人列表，支持模糊搜索
                              filtered_contacts=()
                              for contact in "${original_contacts[@]}"; do
                                  if echo "$contact" | grep -i "$search_query" >/dev/null 2>&1; then
                                      filtered_contacts+=($contact)
                                  fi
                              done
                          else
                              # 清空搜索，恢复原始列表
                              filtered_contacts=(${original_contacts[@]})
                          fi
                          # 重新计算分页信息
                          total_contacts=${#filtered_contacts[@]}
                          total_pages=$(( (total_contacts + current_page_size - 1) / current_page_size ))
                          current_page=1
                          continue ;; 
                    [sS]) read -p "请输入每页显示数量: " new_size
                          if [ "$new_size" -gt 0 ] 2>/dev/null; then
                              current_page_size=$new_size
                              # 重新计算分页信息
                              total_contacts=${#filtered_contacts[@]}
                              total_pages=$(( (total_contacts + current_page_size - 1) / current_page_size ))
                              current_page=1
                          else
                              echo -e "${RED}无效的数量，请输入大于0的数字${NC}"
                              sleep 1
                          fi
                          continue ;; 
                    [nN]) if [ $current_page -lt $total_pages ]; then current_page=$((current_page + 1)); else echo -e "${YELLOW}已经是最后一页${NC}"; sleep 1; fi; continue ;; 
                    [pP]) if [ $current_page -gt 1 ]; then current_page=$((current_page - 1)); else echo -e "${YELLOW}已经是第一页${NC}"; sleep 1; fi; continue ;; 
                esac
                
                # 处理数字选择
                if [ "$contact_choice" -ge 1 ] && [ "$contact_choice" -le $total_contacts ]; then
                    contact=${filtered_contacts[$((contact_choice-1))]}
                    break 2
                else
                    echo -e "${RED}无效选择，请重新输入${NC}"; sleep 1; continue
                fi
            done
        done
        
        # 确认删除
        read -p "确定要删除联系人 '$contact' 吗？(y/n): " confirm
        
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            delete_yaml "$category" "$contact"
        fi
        
        read -p "按 Enter 键返回主菜单..." -n 1
        show_main_menu
    fi
}

# 主程序入口
show_main_menu
