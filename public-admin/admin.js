const API_BASE = '/api';
let contacts = [];
let categories = [];

document.addEventListener('DOMContentLoaded', () => {
    loadData();
    setupEventListeners();
});

function setupEventListeners() {
    document.getElementById('add-btn').addEventListener('click', openAddModal);
    document.getElementById('refresh-btn').addEventListener('click', loadData);
    document.getElementById('search-input').addEventListener('input', debounce(filterContacts, 300));
    document.getElementById('category-filter').addEventListener('change', filterContacts);
    
    document.getElementById('save-btn').addEventListener('click', saveContact);
    document.getElementById('cancel-btn').addEventListener('click', closeModal);
    document.querySelector('.close').addEventListener('click', closeModal);
    
    document.getElementById('add-phone-btn').addEventListener('click', addPhoneField);
    document.getElementById('add-email-btn').addEventListener('click', addEmailField);
    
    document.getElementById('modal').addEventListener('click', (e) => {
        if (e.target === document.getElementById('modal')) {
            closeModal();
        }
    });
}

async function loadData() {
    try {
        const [contactsRes, categoriesRes] = await Promise.all([
            fetch(`${API_BASE}/contacts`),
            fetch(`${API_BASE}/categories`)
        ]);
        
        contacts = await contactsRes.json();
        categories = await categoriesRes.json();
        
        populateCategoryFilter();
        renderContacts();
    } catch (error) {
        console.error('加载数据失败:', error);
        alert('加载数据失败，请检查服务器是否运行');
    }
}

function populateCategoryFilter() {
    const select = document.getElementById('category-filter');
    select.innerHTML = '<option value="all">全部分类</option>';
    categories.forEach(cat => {
        const option = document.createElement('option');
        option.value = cat;
        option.textContent = cat;
        select.appendChild(option);
    });
    
    const formSelect = document.getElementById('form-category');
    formSelect.innerHTML = '<option value="">请选择分类</option>';
    categories.forEach(cat => {
        const option = document.createElement('option');
        option.value = cat;
        option.textContent = cat;
        formSelect.appendChild(option);
    });
}

function renderContacts(filtered = contacts) {
    const grid = document.getElementById('card-grid');
    const loading = document.getElementById('loading');
    
    if (filtered.length === 0) {
        grid.innerHTML = `
            <div class="empty-state">
                <div class="icon">📭</div>
                <h3>没有找到联系人</h3>
                <p>尝试调整搜索条件或添加新联系人</p>
            </div>
        `;
        loading.style.display = 'none';
        return;
    }
    
    loading.style.display = 'none';
    grid.innerHTML = filtered.map(contact => `
        <div class="card" data-id="${contact.category}/${contact.filename}">
            <div class="card-header">
                <img src="${API_BASE}/icon/${contact.category}/${contact.filename}.png" 
                     alt="${contact.organization}" 
                     class="card-icon"
                     onerror="this.src='data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjQiIGhlaWdodD0iNjQiIHZpZXdCb3g9IjAgMCA2NCA2NCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHJlY3Qgd2lkdGg9IjY0IiBoZWlnaHQ9IjY0IiByeD0iMTIiIGZpbGw9IiNGOEY5RkEiLz4KPHBhdGggZD0iTTMyIDE2QTggOCAwIDAgMSA0MCAyNEE4IDggMCAwIDEgMzIgMzJBOCA4IDAgMCAxIDI0IDI0QTggOCAwIDAgMSAzMiAxNloiIGZpbGw9IiM2NjciLz4KPC9zdmc+';"/>
                <div class="card-info">
                    <h3>${contact.organization}</h3>
                    <span class="card-category">${contact.category}</span>
                </div>
            </div>
            <div class="card-phones">
                ${contact.phones.map(p => {
                    if (typeof p === 'object' && p.number) {
                        return `<div class="card-phone">📞 ${p.number} <span class="phone-label">(${p.label})</span></div>`;
                    } else {
                        return `<div class="card-phone">📞 ${p}</div>`;
                    }
                }).join('')}
            </div>
            ${contact.url ? `<div class="card-url">🌐 ${contact.url}</div>` : ''}
            ${contact.emails && contact.emails.length > 0 ? `
                <div class="card-emails">
                    ${contact.emails.map(email => {
                        const emailValue = email.email ? email.email : email;
                        const emailLabel = email.label ? ` (${email.label})` : '';
                        return `<div class="card-email">📧 ${emailValue}${emailLabel}</div>`;
                    }).join('')}
                </div>
            ` : ''}
            <div class="card-actions">
                <button class="btn btn-secondary" onclick="editContact('${contact.category}', '${contact.filename}')">编辑</button>
                <button class="btn btn-danger" onclick="deleteContact('${contact.category}', '${contact.filename}')">删除</button>
            </div>
        </div>
    `).join('');
}

function filterContacts() {
    const searchTerm = document.getElementById('search-input').value.toLowerCase();
    const category = document.getElementById('category-filter').value;
    
    const filtered = contacts.filter(c => {
        const matchesSearch = !searchTerm || 
            c.organization.toLowerCase().includes(searchTerm) ||
            c.phones.some(p => String(p).includes(searchTerm));
        const matchesCategory = category === 'all' || c.category === category;
        return matchesSearch && matchesCategory;
    });
    
    renderContacts(filtered);
}

function openAddModal() {
    document.getElementById('modal-title').textContent = '新增联系人';
    document.getElementById('edit-form').reset();
    document.getElementById('form-id').value = '';
    document.getElementById('phone-list').innerHTML = `
        <div class="phone-item">
            <input type="text" class="phone-input" placeholder="电话号码">
            <input type="text" class="phone-label-input" placeholder="标签（可选）">
            <button type="button" class="remove-phone-btn">×</button>
        </div>
    `;
    document.getElementById('email-list').innerHTML = `
        <div class="email-item">
            <input type="email" class="email-input" placeholder="工作邮箱">
            <input type="text" class="email-label-input" placeholder="标签（可选）">
            <button type="button" class="remove-email-btn">×</button>
        </div>
    `;
    document.getElementById('modal').style.display = 'flex';
}

function editContact(category, filename) {
    const contact = contacts.find(c => c.category === category && c.filename === filename);
    if (!contact) return;
    
    document.getElementById('modal-title').textContent = '编辑联系人';
    document.getElementById('edit-form').reset();
    document.getElementById('form-id').value = `${category}/${filename}`;
    document.getElementById('form-original-category').value = category;
    document.getElementById('form-original-filename').value = filename;
    document.getElementById('form-category').value = category;
    document.getElementById('form-organization').value = contact.organization;
    document.getElementById('form-url').value = contact.url || '';
    
    const phoneList = document.getElementById('phone-list');
    phoneList.innerHTML = contact.phones.map((phone, index) => {
        const phoneNumber = phone.number ? phone.number : phone;
        const phoneLabel = phone.label || '';
        return `
            <div class="phone-item">
                <input type="text" class="phone-input" value="${phoneNumber}">
                <input type="text" class="phone-label-input" value="${phoneLabel}" placeholder="标签（可选）">
                <button type="button" class="remove-phone-btn" ${index === 0 ? 'style="display:none"' : ''}>×</button>
            </div>
        `;
    }).join('');
    
    const emailList = document.getElementById('email-list');
    const emails = contact.emails || [];
    emailList.innerHTML = emails.map((email, index) => {
        const emailValue = email.email ? email.email : email;
        const emailLabel = email.label || '';
        return `
            <div class="email-item">
                <input type="email" class="email-input" value="${emailValue}">
                <input type="text" class="email-label-input" value="${emailLabel}" placeholder="标签（可选）">
                <button type="button" class="remove-email-btn" ${index === 0 && emails.length <= 1 ? 'style="display:none"' : ''}>×</button>
            </div>
        `;
    }).join('');
    
    document.getElementById('modal').style.display = 'flex';
}

function addPhoneField() {
    const phoneList = document.getElementById('phone-list');
    phoneList.insertAdjacentHTML('beforeend', `
        <div class="phone-item">
            <input type="text" class="phone-input" placeholder="电话号码">
            <input type="text" class="phone-label-input" placeholder="标签（可选）">
            <button type="button" class="remove-phone-btn">×</button>
        </div>
    `);
    bindRemovePhoneEvents();
}

function bindRemovePhoneEvents() {
    document.querySelectorAll('.remove-phone-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const items = document.querySelectorAll('.phone-item');
            if (items.length > 1) {
                this.parentElement.remove();
            }
        });
    });
}

function addEmailField() {
    const emailList = document.getElementById('email-list');
    emailList.insertAdjacentHTML('beforeend', `
        <div class="email-item">
            <input type="email" class="email-input" placeholder="工作邮箱">
            <input type="text" class="email-label-input" placeholder="标签（可选）">
            <button type="button" class="remove-email-btn">×</button>
        </div>
    `);
    bindRemoveEmailEvents();
}

function bindRemoveEmailEvents() {
    document.querySelectorAll('.remove-email-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const items = document.querySelectorAll('.email-item');
            if (items.length > 1) {
                this.parentElement.remove();
            }
        });
    });
}

async function saveContact() {
    const form = document.getElementById('edit-form');
    if (!form.checkValidity()) {
        form.reportValidity();
        return;
    }
    
    const id = document.getElementById('form-id').value;
    const category = document.getElementById('form-category').value;
    const organization = document.getElementById('form-organization').value;
    const url = document.getElementById('form-url').value;
    const iconFile = document.getElementById('form-icon').files[0];
    
    const phoneItems = document.querySelectorAll('.phone-item');
    const phones = [];
    
    phoneItems.forEach(item => {
        const phoneInput = item.querySelector('.phone-input');
        const labelInput = item.querySelector('.phone-label-input');
        const phoneNumber = phoneInput.value.trim();
        const phoneLabel = labelInput.value.trim();
        
        if (phoneNumber) {
            if (phoneLabel) {
                phones.push({ number: phoneNumber, label: phoneLabel });
            } else {
                phones.push(phoneNumber);
            }
        }
    });
    
    if (phones.length === 0) {
        alert('请至少添加一个电话号码');
        return;
    }
    
    const emailItems = document.querySelectorAll('.email-item');
    const emails = [];
    emailItems.forEach(item => {
        const emailInput = item.querySelector('.email-input');
        const labelInput = item.querySelector('.email-label-input');
        const emailValue = emailInput.value.trim();
        const emailLabel = labelInput.value.trim();
        if (emailValue) {
            if (emailLabel) {
                emails.push({ email: emailValue, label: emailLabel });
            } else {
                emails.push(emailValue);
            }
        }
    });
    
    const filename = organization.replace(/[\/:*?"<>|]/g, '_');
    
    try {
        const formData = new FormData();
        formData.append('organization', organization);
        formData.append('category', category);
        formData.append('url', url);
        
        phones.forEach((phone, index) => {
            if (typeof phone === 'object') {
                formData.append(`phones[${index}][number]`, phone.number);
                formData.append(`phones[${index}][label]`, phone.label);
            } else {
                formData.append(`phones[${index}]`, phone);
            }
        });
        
        emails.forEach((email, index) => {
            if (typeof email === 'object') {
                formData.append(`emails[${index}][email]`, email.email);
                formData.append(`emails[${index}][label]`, email.label);
            } else {
                formData.append(`emails[${index}]`, email);
            }
        });
        
        if (iconFile) {
            formData.append('icon', iconFile);
        }
        
        const method = id ? 'PUT' : 'POST';
        
        const originalCategory = document.getElementById('form-original-category').value;
        const originalFilename = document.getElementById('form-original-filename').value;
        
        let urlPath;
        if (id) {
            urlPath = `${API_BASE}/contacts/${originalCategory}/${originalFilename}`;
        } else {
            urlPath = `${API_BASE}/contacts/${category}/${filename}`;
        }
        
        const response = await fetch(urlPath, {
            method: method,
            body: formData
        });
        
        if (response.ok) {
            alert(id ? '修改成功' : '添加成功');
            closeModal();
            loadData();
        } else {
            const error = await response.json();
            alert(error.message || '操作失败');
        }
    } catch (error) {
        console.error('保存失败:', error);
        alert('保存失败，请检查服务器');
    }
}

async function deleteContact(category, filename) {
    if (!confirm(`确定要删除「${getContactName(category, filename)}」吗？`)) {
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}/contacts/${category}/${filename}`, {
            method: 'DELETE'
        });
        
        if (response.ok) {
            alert('删除成功');
            loadData();
        } else {
            alert('删除失败');
        }
    } catch (error) {
        console.error('删除失败:', error);
        alert('删除失败');
    }
}

function getContactName(category, filename) {
    const contact = contacts.find(c => c.category === category && c.filename === filename);
    return contact ? contact.organization : filename;
}

function closeModal() {
    document.getElementById('modal').style.display = 'none';
}

function debounce(func, wait) {
    let timeout;
    return function(...args) {
        clearTimeout(timeout);
        timeout = setTimeout(() => func(...args), wait);
    };
}