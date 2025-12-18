#!/bin/bash

# 修复后的查看联系人函数
function view_contacts() {
    local show_categories=true
    local selected_category=""
    local show_all_search=false
    local all_search_query=""
    
    while true; do
        clear
        echo -e "${BLUE}=====================================${NC}"
        if [ "$show_categories" = true ]; then
            echo -e "${BLUE}            查看联系人${NC}"
        elif [ "$show_all_search" = true ]; then
            echo -e "${BLUE}            搜索结果${NC}"
            echo -e "${BLUE}          关键词: $all_search_query${NC}"
        else
            echo -e "${BLUE}          分类: $selected_category${NC}"
        fi
        echo -e "${BLUE}=====================================${NC}"
        
        if [ "$show_categories" = true ]; then
            echo -e "${YELLOW}【快捷操作】: m.返回主菜单 | q.退出程序 | f.搜索联系人 | s.自定义每页显示数量 (当前: $current_page_size)${NC}"
            echo -e "${BLUE}-------------------------------------${NC}"
            echo -e "${YELLOW}请选择分类或直接搜索联系人:${NC}"
            
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
            local total_categories=${#filtered_categories[@]}
            local total_pages=$(( (total_categories + current_page_size - 1) / current_page_size ))
            local current_page=1
            
            while true; do
                clear
                echo -e "${BLUE}=====================================${NC}"
                echo -e "${BLUE}            查看联系人${NC}"
                echo -e "${BLUE}=====================================${NC}"
                echo -e "${YELLOW}【快捷操作】: m.返回主菜单 | q.退出程序 | f.搜索联系人 | s.自定义每页显示数量 (当前: $current_page_size)${NC}"
                echo -e "${BLUE}-------------------------------------${NC}"
                echo -e "${YELLOW}请选择分类或直接搜索联系人:${NC}"
                echo -e "${YELLOW}第 $current_page/$total_pages 页，共 $total_categories 个分类${NC}"
                echo -e "${BLUE}-------------------------------------${NC}"
                
                # 显示当前页的分类
                local start_idx=$(( (current_page - 1) * current_page_size ))
                local end_idx=$(( start_idx + current_page_size - 1 ))
                if [ $end_idx -ge $total_categories ]; then
                    end_idx=$((total_categories - 1))
                fi
                
                for ((i=start_idx; i<=end_idx; i++)); do
                    echo -e "${YELLOW}$((i+1)). ${filtered_categories[$i]}${NC}"
                done
                
                echo -e "${BLUE}-------------------------------------${NC}"
                echo -e "${YELLOW}分页导航: p.上一页 | n.下一页${NC}"
                
                # 读取用户选择
                read -p "请输入选择: " choice
                
                case "$choice" in
                    [mM]) show_main_menu; return ;;
                    [qQ]) echo -e "${GREEN}谢谢使用！${NC}"; exit 0 ;;
                    [fF]) # 搜索联系人
                          read -p "请输入搜索关键词 (直接回车清空搜索): " all_search_query
                          if [ -n "$all_search_query" ]; then
                              show_all_search=true
                              show_categories=false
                              break
                          fi
                          continue ;; 
                    [sS]) read -p "请输入每页显示数量: " new_size
                          if [ "$new_size" -gt 0 ]; then
                              current_page_size=$new_size
                          fi
                          total_pages=$(( (total_categories + current_page_size - 1) / current_page_size ))
                          current_page=1
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
                    *) # 数字选择
                       local num_choice=$choice
                       if [ "$num_choice" -ge 1 ] && [ "$num_choice" -le $total_categories ]; then
                           selected_category=${filtered_categories[$((num_choice-1))]}
                           show_categories=false
                           break
                       else
                           echo -e "${RED}无效选择，请重新输入${NC}"
                           sleep 1
                       fi
                       continue ;; 
                esac
            done
        fi
        
        if [ "$show_all_search" = true ]; then
            echo -e "${YELLOW}【快捷操作】: m.返回主菜单 | b.返回分类列表 | q.退出程序 | f.搜索 | s.自定义每页显示数量 (当前: $current_page_size)${NC}"
            echo -e "${BLUE}-------------------------------------${NC}"
            
            # 获取所有联系人
            all_contacts=($(get_all_contacts))
            local original_all_contacts=(${all_contacts[@]})
            local filtered_contacts=(${original_all_contacts[@]})
            
            # 过滤联系人
            if [ -n "$all_search_query" ]; then
                filtered_contacts=()
                for contact_item in "${original_all_contacts[@]}"; do
                    local category=$(echo "$contact_item" | cut -d':' -f1)
                    local contact=$(echo "$contact_item" | cut -d':' -f2)
                    if echo "$contact" | grep -i "$all_search_query" >/dev/null 2>&1; then
                        filtered_contacts+=($contact_item)
                    fi
                done
            fi
            
            local total_contacts=${#filtered_contacts[@]}
            local total_pages=$(( (total_contacts + current_page_size - 1) / current_page_size ))
            local current_page=1
            
            while true; do
                clear
                echo -e "${BLUE}=====================================${NC}"
                echo -e "${BLUE}            搜索结果${NC}"
                echo -e "${BLUE}          关键词: $all_search_query${NC}"
                echo -e "${BLUE}=====================================${NC}"
                echo -e "${YELLOW}【快捷操作】: m.返回主菜单 | b.返回分类列表 | q.退出程序 | f.搜索 | s.自定义每页显示数量 (当前: $current_page_size)${NC}"
                echo -e "${BLUE}-------------------------------------${NC}"
                echo -e "${YELLOW}请选择联系人:${NC}"
                echo -e "${YELLOW}第 $current_page/$total_pages 页，共 $total_contacts 个联系人${NC}"
                echo -e "${BLUE}-------------------------------------${NC}"
                
                # 显示当前页的联系人
                local start_idx=$(( (current_page - 1) * current_page_size ))
                local end_idx=$(( start_idx + current_page_size - 1 ))
                if [ $end_idx -ge $total_contacts ]; then
                    end_idx=$((total_contacts - 1))
                fi
                
                for ((i=start_idx; i<=end_idx; i++)); do
                    local contact_item=${filtered_contacts[$i]}
                    local category=$(echo "$contact_item" | cut -d':' -f1)
                    local contact=$(echo "$contact_item" | cut -d':' -f2)
                    echo -e "${YELLOW}$((i+1)). ${contact} (${category})${NC}"
                done
                
                echo -e "${BLUE}-------------------------------------${NC}"
                echo -e "${YELLOW}分页导航: p.上一页 | n.下一页${NC}"
                
                # 读取用户选择
                read -p "请输入选择: " choice
                
                case "$choice" in
                    [mM]) show_main_menu; return ;;
                    [qQ]) echo -e "${GREEN}谢谢使用！${NC}"; exit 0 ;;
                    [bB]) # 返回分类列表
                          show_categories=true
                          show_all_search=false
                          break ;;
                    [fF]) # 重新搜索
                          read -p "请输入搜索关键词: " all_search_query
                          if [ -n "$all_search_query" ]; then
                              # 重新过滤
                              filtered_contacts=()
                              for contact_item in "${original_all_contacts[@]}"; do
                                  local contact=$(echo "$contact_item" | cut -d':' -f2)
                                  if echo "$contact" | grep -i "$all_search_query" >/dev/null 2>&1; then
                                      filtered_contacts+=($contact_item)
                                  fi
                              done
                              # 重新计算分页
                              total_contacts=${#filtered_contacts[@]}
                              total_pages=$(( (total_contacts + current_page_size - 1) / current_page_size ))
                              current_page=1
                              continue ;;
                    [sS]) read -p "请输入每页显示数量: " new_size
                          if [ "$new_size" -gt 0 ]; then
                              current_page_size=$new_size
                          fi
                          total_pages=$(( (total_contacts + current_page_size - 1) / current_page_size ))
                          current_page=1
                          continue ;;
                    [nN]) # 下一页
                          if [ $current_page -lt $total_pages ]; then
                              current_page=$((current_page + 1))
                          else
                              echo -e "${YELLOW}已经是最后一页${NC}"
                              sleep 1
                          fi
                          continue ;;
                    [pP]) # 上一页
                          if [ $current_page -gt 1 ]; then
                              current_page=$((current_page - 1))
                          else
                              echo -e "${YELLOW}已经是第一页${NC}"
                              sleep 1
                          fi
                          continue ;;
                    *) # 选择联系人
                       local num_choice=$choice
                       if [ "$num_choice" -ge 1 ] && [ "$num_choice" -le $total_contacts ]; then
                           # 处理联系人选择
                           local selected_item=${filtered_contacts[$((num_choice-1))]}
                           local category=$(echo "$selected_item" | cut -d':' -f1)
                           local contact=$(echo "$selected_item" | cut -d':' -f2)
                           
                           # 显示联系人详情
                           clear
                           echo -e "${BLUE}=====================================${NC}"
                           echo -e "${BLUE}          分类: $category${NC}"
                           echo -e "${BLUE}          联系人: $contact${NC}"
                           echo -e "${BLUE}=====================================${NC}"
                           
                           # 读取联系人信息
                           local yaml_content=$(read_yaml "$category" "$contact")
                           local organization=$(get_yaml_field "$yaml_content" "organization")
                           local cell_phone=$(get_yaml_field "$yaml_content" "cellPhone" | tr '\n' ', ' | sed 's/,$//')
                           local url=$(get_yaml_field "$yaml_content" "url")
                           local work_email=$(get_yaml_field "$yaml_content" "workEmail" | tr '\n' ', ' | sed 's/,$//')
                           
                           echo -e "${YELLOW}组织名称:${NC} $organization"
                           echo -e "${YELLOW}电话号码:${NC} ${cell_phone:-无}"
                           echo -e "${YELLOW}网址:${NC} ${url:-无}"
                           echo -e "${YELLOW}邮箱:${NC} ${work_email:-无}"
                           echo -e "${BLUE}=====================================${NC}"
                           
                           read -p "按 Enter 键返回..." -n 1
                           break ;;
                       else
                           echo -e "${RED}无效选择，请重新输入${NC}"
                           sleep 1
                       fi
                       continue ;;
                esac
            done
        fi
        
        if [ "$show_categories" = false ] && [ "$show_all_search" = false ]; then
            echo -e "${YELLOW}【快捷操作】: m.返回主菜单 | b.返回分类列表 | q.退出程序 | s.自定义每页显示数量 (当前: $current_page_size)${NC}"
            echo -e "${BLUE}-------------------------------------${NC}"
            echo -e "${YELLOW}请选择联系人:${NC}"
            
            # 获取该分类下的联系人
            contacts=($(get_yaml_files "$selected_category"))
            if [ ${#contacts[@]} -eq 0 ]; then
                echo -e "${RED}该分类下没有联系人${NC}"
                read -p "按 Enter 键返回分类列表..." -n 1
                show_categories=true
                continue
            fi
            
            # 分页显示联系人
            local original_contacts=(${contacts[@]})
            local filtered_contacts=(${original_contacts[@]})
            local total_contacts=${#filtered_contacts[@]}
            local total_pages=$(( (total_contacts + current_page_size - 1) / current_page_size ))
            local current_page=1
            
            while true; do
                clear
                echo -e "${BLUE}=====================================${NC}"
                echo -e "${BLUE}          分类: $selected_category${NC}"
                echo -e "${BLUE}=====================================${NC}"
                echo -e "${YELLOW}【快捷操作】: m.返回主菜单 | b.返回分类列表 | q.退出程序 | f.搜索 | s.自定义每页显示数量 (当前: $current_page_size)${NC}"
                echo -e "${BLUE}-------------------------------------${NC}"
                echo -e "${YELLOW}请选择联系人:${NC}"
                echo -e "${YELLOW}第 $current_page/$total_pages 页，共 $total_contacts 个联系人${NC}"
                echo -e "${BLUE}-------------------------------------${NC}"
                
                # 显示当前页的联系人
                local start_idx=$(( (current_page - 1) * current_page_size ))
                local end_idx=$(( start_idx + current_page_size - 1 ))
                if [ $end_idx -ge $total_contacts ]; then
                    end_idx=$((total_contacts - 1))
                fi
                
                for ((i=start_idx; i<=end_idx; i++)); do
                    echo -e "${YELLOW}$((i+1)). ${filtered_contacts[$i]}${NC}"
                done
                
                echo -e "${BLUE}-------------------------------------${NC}"
                echo -e "${YELLOW}分页导航: p.上一页 | n.下一页${NC}"
                
                # 读取用户选择
                read -p "请输入选择: " choice
                
                case "$choice" in
                    [mM]) show_main_menu; return ;;
                    [qQ]) echo -e "${GREEN}谢谢使用！${NC}"; exit 0 ;;
                    [bB]) show_categories=true; break ;;
                    [fF]) # 搜索当前分类下的联系人
                          read -p "请输入搜索关键词: " search_query
                          if [ -n "$search_query" ]; then
                              filtered_contacts=()
                              for contact in "${original_contacts[@]}"; do
                                  if echo "$contact" | grep -i "$search_query" >/dev/null 2>&1; then
                                      filtered_contacts+=($contact)
                                  fi
                              done
                              total_contacts=${#filtered_contacts[@]}
                              total_pages=$(( (total_contacts + current_page_size - 1) / current_page_size ))
                              current_page=1
                          else
                              filtered_contacts=(${original_contacts[@]})
                              total_contacts=${#filtered_contacts[@]}
                              total_pages=$(( (total_contacts + current_page_size - 1) / current_page_size ))
                              current_page=1
                          fi
                          continue ;;
                    [sS]) read -p "请输入每页显示数量: " new_size
                          if [ "$new_size" -gt 0 ]; then
                              current_page_size=$new_size
                          fi
                          total_pages=$(( (total_contacts + current_page_size - 1) / current_page_size ))
                          current_page=1
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
                    *) # 选择联系人
                       local num_choice=$choice
                       if [ "$num_choice" -ge 1 ] && [ "$num_choice" -le $total_contacts ]; then
                           contact=${filtered_contacts[$((num_choice-1))]}
                           
                           # 显示联系人详情
                           clear
                           echo -e "${BLUE}=====================================${NC}"
                           echo -e "${BLUE}          分类: $selected_category${NC}"
                           echo -e "${BLUE}          联系人: $contact${NC}"
                           echo -e "${BLUE}=====================================${NC}"
                           
                           # 读取联系人信息
                           local yaml_content=$(read_yaml "$selected_category" "$contact")
                           local organization=$(get_yaml_field "$yaml_content" "organization")
                           local cell_phone=$(get_yaml_field "$yaml_content" "cellPhone" | tr '\n' ', ' | sed 's/,$//')
                           local url=$(get_yaml_field "$yaml_content" "url")
                           local work_email=$(get_yaml_field "$yaml_content" "workEmail" | tr '\n' ', ' | sed 's/,$//')
                           
                           echo -e "${YELLOW}组织名称:${NC} $organization"
                           echo -e "${YELLOW}电话号码:${NC} ${cell_phone:-无}"
                           echo -e "${YELLOW}网址:${NC} ${url:-无}"
                           echo -e "${YELLOW}邮箱:${NC} ${work_email:-无}"
                           echo -e "${BLUE}=====================================${NC}"
                           
                           read -p "按 Enter 键返回..." -n 1
                           break ;;
                       else
                           echo -e "${RED}无效选择，请重新输入${NC}"
                           sleep 1
                       fi
                       continue ;;
                esac
            done
        fi
    done
}
