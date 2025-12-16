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
$(echo "$cell_phone" | awk '{for(i=1;i<=NF;i++) print "    - "$i}')
$(if [ -n "$url" ]; then echo "  url: $url"; fi)
$(if [ -n "$work_email" ]; then 
    echo "  workEmail:";
    echo "$work_email" | awk '{for(i=1;i<=NF;i++) print "    - "$i}';
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
    local show_categories=true
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
            local total_categories
            local total_pages
            local current_page
            total_categories=${#categories[@]}
            total_pages=$(( (total_categories + current_page_size - 1) / current_page_size ))
            current_page=1
            
            while true; do
                clear
                echo -e "${BLUE}=====================================${NC}"
                echo -e "${BLUE}            查看联系人${NC}"
                echo -e "${BLUE}=====================================${NC}"
                echo -e "${YELLOW}【快捷操作】: m.返回主菜单 | q.退出程序 | s.自定义每页显示数量 (当前: $current_page_size)${NC}"
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
                    echo -e "${YELLOW}$((i+1)). ${categories[$i]}${NC}"
                done
                
                # 显示分页导航
                echo -e "${BLUE}-------------------------------------${NC}"
                echo -e "${YELLOW}分页导航: n.下一页 | p.上一页 | 页码直接跳转 | m.返回主菜单 | q.退出程序 | s.自定义每页显示数量${NC}"
                
                # 读取用户选择
                read -p "请输入选择: " choice
                
                # 处理字母快捷操作
                case "$choice" in
                    [mM]) show_main_menu; return ;;
                    [qQ]) echo -e "${GREEN}谢谢使用！${NC}"; exit 0 ;;
                    [sS]) read -p "请输入每页显示数量: " new_size
                          if [ "$new_size" -gt 0 ] 2>/dev/null; then
                              current_page_size=$new_size
                              # 重新计算分页信息
                              total_categories=${#categories[@]}
                              total_pages=$(( (total_categories + current_page_size - 1) / current_page_size ))
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
                if [ "$choice" -ge 1 ] && [ "$choice" -le $total_categories ]; then
                    selected_category=${categories[$((choice-1))]}
                    show_categories=false
                    break
                elif [ "$choice" -ge 1 ] && [ "$choice" -le $total_pages ]; then
                    current_page=$choice
                    continue
                else
                    echo -e "${RED}无效选择，请重新输入${NC}"
                    sleep 1
                    continue
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
            local total_contacts
            local total_pages
            local current_page
            total_contacts=${#contacts[@]}
            total_pages=$(( (total_contacts + current_page_size - 1) / current_page_size ))
            current_page=1
            
            while true; do
                clear
                echo -e "${BLUE}=====================================${NC}"
                echo -e "${BLUE}          分类: $selected_category${NC}"
                echo -e "${BLUE}=====================================${NC}"
                echo -e "${YELLOW}【快捷操作】: m.返回主菜单 | b.返回分类列表 | q.退出程序 | s.自定义每页显示数量 (当前: $current_page_size)${NC}"
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
                    echo -e "${YELLOW}$((i+1)). ${contacts[$i]}${NC}"
                done
                
                # 显示分页导航
                echo -e "${BLUE}-------------------------------------${NC}"
                echo -e "${YELLOW}分页导航: n.下一页 | p.上一页 | 页码直接跳转 | b.返回分类列表 | m.返回主菜单 | q.退出程序 | s.自定义每页显示数量${NC}"
                
                # 读取用户选择
                read -p "请输入选择: " choice
                
                # 处理字母快捷操作
                case "$choice" in
                    [mM]) show_main_menu; return ;;
                    [bB]) show_categories=true
                          break ;;
                    [qQ]) echo -e "${GREEN}谢谢使用！${NC}"; exit 0 ;;
                    [sS]) read -p "请输入每页显示数量: " new_size
                          if [ "$new_size" -gt 0 ] 2>/dev/null; then
                              current_page_size=$new_size
                              # 重新计算分页信息
                              total_contacts=${#contacts[@]}
                              total_pages=$(( (total_contacts + current_page_size - 1) / current_page_size ))
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
                if [ "$choice" -ge 1 ] && [ "$choice" -le $total_contacts ]; then
                    contact=${contacts[$((choice-1))]}
                    
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
                elif [ "$choice" -ge 1 ] && [ "$choice" -le $total_pages ]; then
                    current_page=$choice
                    continue
                else
                    echo -e "${RED}无效选择，请重新输入${NC}"
                    sleep 1
                    continue
                fi
            done
        fi
    done
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
    echo -e "${YELLOW}请选择分类:${NC}"
    
    # 显示分类编号和名称
    for i in "${!categories[@]}"; do
        echo -e "${YELLOW}$((i+1)). ${categories[$i]}${NC}"
    done
    
    read -p "请输入选择 [1-${#categories[@]}], c.取消: " category_choice
    
    # 检查是否取消
    if [ "$category_choice" = "c" ] || [ "$category_choice" = "C" ]; then
        echo -e "${GREEN}已取消创建联系人${NC}"
        sleep 1
        show_main_menu
        return
    fi
    
    # 验证分类选择
    if [ "$category_choice" -ge 1 ] && [ "$category_choice" -le ${#categories[@]} ]; then
        category=${categories[$((category_choice-1))]}
    else
        echo -e "${RED}无效选择，请重新输入${NC}"
        sleep 1
        create_contact
        return
    fi
    
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
    
    # 显示分类菜单
    echo -e "${YELLOW}请选择分类:${NC}"
    
    # 显示分类编号和名称
    for i in "${!categories[@]}"; do
        echo -e "${YELLOW}$((i+1)). ${categories[$i]}${NC}"
    done
    
    # 读取用户选择
    read -p "请输入选择 [1-${#categories[@]}], c.取消: " category_choice
    
    # 检查是否取消
    if [ "$category_choice" = "c" ] || [ "$category_choice" = "C" ]; then
        echo -e "${GREEN}已取消编辑联系人${NC}"
        sleep 1
        show_main_menu
        return
    fi
    
    # 验证分类选择
    if [ "$category_choice" -ge 1 ] && [ "$category_choice" -le ${#categories[@]} ]; then
        category=${categories[$((category_choice-1))]}
    else
        echo -e "${RED}无效选择，请重新输入${NC}"
        sleep 1
        edit_contact
        return
    fi
    
    # 获取联系人列表
    contacts=($(get_yaml_files "$category"))
    if [ ${#contacts[@]} -eq 0 ]; then
        echo -e "${RED}该分类下没有联系人${NC}"
        read -p "按 Enter 键返回主菜单..." -n 1
        show_main_menu
        return
    fi
    
    # 显示联系人菜单
    echo -e "${YELLOW}请选择联系人:${NC}"
    
    # 显示联系人编号和名称
    for i in "${!contacts[@]}"; do
        echo -e "${YELLOW}$((i+1)). ${contacts[$i]}${NC}"
    done
    
    # 读取用户选择
    read -p "请输入选择 [1-${#contacts[@]}], c.取消: " contact_choice
    
    # 检查是否取消
    if [ "$contact_choice" = "c" ] || [ "$contact_choice" = "C" ]; then
        echo -e "${GREEN}已取消编辑联系人${NC}"
        sleep 1
        show_main_menu
        return
    fi
    
    # 验证联系人选择
    if [ "$contact_choice" -ge 1 ] && [ "$contact_choice" -le ${#contacts[@]} ]; then
        contact=${contacts[$((contact_choice-1))]}
    else
        echo -e "${RED}无效选择，请重新输入${NC}"
        sleep 1
        edit_contact
        return
    fi
    
    # 读取当前联系人信息
    yaml_content=$(read_yaml "$category" "$contact")
    
    # 解析当前字段值
    current_organization=$(get_yaml_field "$yaml_content" "organization")
    current_cell_phone=$(get_yaml_field "$yaml_content" "cellPhone" | tr '\n' ' ')
    current_url=$(get_yaml_field "$yaml_content" "url")
    current_work_email=$(get_yaml_field "$yaml_content" "workEmail" | tr '\n' ' ')
    
    # 输入新的联系人信息，支持默认值
    read -p "请输入组织名称 [$current_organization] (c.取消): " organization
    if [ "$organization" = "c" ] || [ "$organization" = "C" ]; then
        echo -e "${GREEN}已取消编辑联系人${NC}"
        sleep 1
        show_main_menu
        return
    fi
    organization=${organization:-$current_organization}
    
    read -p "请输入电话号码 [$current_cell_phone] (c.取消): " cell_phone
    if [ "$cell_phone" = "c" ] || [ "$cell_phone" = "C" ]; then
        echo -e "${GREEN}已取消编辑联系人${NC}"
        sleep 1
        show_main_menu
        return
    fi
    cell_phone=${cell_phone:-$current_cell_phone}
    
    read -p "请输入网址 [$current_url] (c.取消): " url
    if [ "$url" = "c" ] || [ "$url" = "C" ]; then
        echo -e "${GREEN}已取消编辑联系人${NC}"
        sleep 1
        show_main_menu
        return
    fi
    url=${url:-$current_url}
    
    read -p "请输入邮箱 [$current_work_email] (c.取消): " work_email
    if [ "$work_email" = "c" ] || [ "$work_email" = "C" ]; then
        echo -e "${GREEN}已取消编辑联系人${NC}"
        sleep 1
        show_main_menu
        return
    fi
    work_email=${work_email:-$current_work_email}
    
    # 确认保存
    echo -e "${BLUE}-------------------------------------${NC}"
    echo -e "${YELLOW}确认保存联系人修改吗？${NC}"
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
        save_yaml "$category" "$contact" "$yaml_content"
    else
        echo -e "${GREEN}已取消编辑联系人${NC}"
    fi
    
    read -p "按 Enter 键返回主菜单..." -n 1
    show_main_menu
}

# 删除联系人
function delete_contact() {
    clear
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}            删除联系人${NC}"
    echo -e "${BLUE}=====================================${NC}"
    
    # 顶部快捷操作栏
    echo -e "${YELLOW}【快捷操作】: m.返回主菜单 | q.退出程序${NC}"
    echo -e "${BLUE}-------------------------------------${NC}"
    
    # 获取分类列表
    categories=($(get_categories))
    if [ ${#categories[@]} -eq 0 ]; then
        echo -e "${RED}没有找到分类${NC}"
        read -p "按 Enter 键返回主菜单..." -n 1
        show_main_menu
        return
    fi
    
    # 显示分类菜单
    echo -e "${YELLOW}请选择分类:${NC}"
    
    # 显示分类编号和名称
    for i in "${!categories[@]}"; do
        echo -e "${YELLOW}$((i+1)). ${categories[$i]}${NC}"
    done
    
    # 读取用户选择
    read -p "请输入选择 [1-${#categories[@]}]: " category_choice
    
    # 验证分类选择
    if [ "$category_choice" -ge 1 ] && [ "$category_choice" -le ${#categories[@]} ]; then
        category=${categories[$((category_choice-1))]}
    else
        echo -e "${RED}无效选择，请重新输入${NC}"
        sleep 1
        delete_contact
        return
    fi
    
    # 获取联系人列表
    contacts=($(get_yaml_files "$category"))
    if [ ${#contacts[@]} -eq 0 ]; then
        echo -e "${RED}该分类下没有联系人${NC}"
        read -p "按 Enter 键返回主菜单..." -n 1
        show_main_menu
        return
    fi
    
    # 显示联系人菜单
    echo -e "${YELLOW}请选择联系人:${NC}"
    
    # 显示联系人编号和名称
    for i in "${!contacts[@]}"; do
        echo -e "${YELLOW}$((i+1)). ${contacts[$i]}${NC}"
    done
    
    # 读取用户选择
    read -p "请输入选择 [1-${#contacts[@]}]: " contact_choice
    
    # 验证联系人选择
    if [ "$contact_choice" -ge 1 ] && [ "$contact_choice" -le ${#contacts[@]} ]; then
        contact=${contacts[$((contact_choice-1))]}
    else
        echo -e "${RED}无效选择，请重新输入${NC}"
        sleep 1
        delete_contact
        return
    fi
    
    # 确认删除
    read -p "确定要删除联系人 '$contact' 吗？(y/n): " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        delete_yaml "$category" "$contact"
    fi
    
    read -p "按 Enter 键返回主菜单..." -n 1
    show_main_menu
}

# 主程序入口
show_main_menu
