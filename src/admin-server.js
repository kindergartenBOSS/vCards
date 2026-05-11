#!/usr/bin/env node

import { createServer } from 'node:http'
import { readFile, writeFile, unlink, readdir, mkdir } from 'node:fs/promises'
import { existsSync, mkdirSync } from 'node:fs'
import * as path from 'node:path'
import { fileURLToPath } from 'node:url'
import yaml from 'js-yaml'
import Busboy from 'busboy'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const DATA_DIR = path.resolve(__dirname, '../data')
const PUBLIC_DIR = path.resolve(__dirname, '../public-admin')
const PORT = process.env.ADMIN_PORT || 3002

const mimeTypes = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.css': 'text/css',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon'
}

function getMimeType(filePath) {
  const ext = path.extname(filePath).toLowerCase()
  return mimeTypes[ext] || 'application/octet-stream'
}

async function getCategories() {
  const entries = await readdir(DATA_DIR, { withFileTypes: true })
  return entries.filter(entry => entry.isDirectory()).map(entry => entry.name)
}

async function getContacts() {
  const categories = await getCategories()
  const contacts = []
  
  for (const category of categories) {
    const categoryPath = path.join(DATA_DIR, category)
    const files = await readdir(categoryPath)
    const yamlFiles = files.filter(f => f.endsWith('.yaml'))
    
    for (const yamlFile of yamlFiles) {
      const filePath = path.join(categoryPath, yamlFile)
      const content = await readFile(filePath, 'utf8')
      const data = yaml.load(content)
      
      if (data && data.basic) {
        const filename = yamlFile.replace('.yaml', '')
        contacts.push({
          organization: data.basic.organization,
          phones: data.basic.cellPhone || [],
          url: data.basic.url || null,
          emails: data.basic.workEmail || [],
          category: category,
          filename: filename
        })
      }
    }
  }
  
  return contacts
}

async function saveContact(category, filename, data) {
  const categoryPath = path.join(DATA_DIR, category)
  
  if (!existsSync(categoryPath)) {
    await mkdir(categoryPath, { recursive: true })
  }
  
  const yamlPath = path.join(categoryPath, `${filename}.yaml`)
  const pngPath = path.join(categoryPath, `${filename}.png`)
  
  const yamlData = {
    basic: {
      organization: data.organization,
      cellPhone: data.phones || [],
      url: data.url || undefined
    }
  }
  
  if (data.emails && data.emails.length > 0) {
    yamlData.basic.workEmail = data.emails
  }
  
  await writeFile(yamlPath, yaml.dump(yamlData))
  
  if (data.icon) {
    await writeFile(pngPath, data.icon)
  }
  
  return true
}

async function deleteContact(category, filename) {
  const yamlPath = path.join(DATA_DIR, category, `${filename}.yaml`)
  const pngPath = path.join(DATA_DIR, category, `${filename}.png`)
  
  if (existsSync(yamlPath)) {
    await unlink(yamlPath)
  }
  
  if (existsSync(pngPath)) {
    await unlink(pngPath)
  }
  
  return true
}

const server = createServer(async (req, res) => {
  try {
    let filePath = req.url === '/' ? '/admin.html' : req.url
    filePath = filePath.split('?')[0]
    filePath = decodeURIComponent(filePath)
    
    if (filePath.includes('..')) {
      res.writeHead(403, { 'Content-Type': 'application/json' })
      res.end(JSON.stringify({ message: 'Forbidden' }))
      return
    }
    
    if (filePath.startsWith('/api/')) {
      await handleApiRequest(req, res, filePath)
      return
    }
    
    const fullPath = path.join(PUBLIC_DIR, filePath)
    
    if (!existsSync(fullPath)) {
      res.writeHead(404, { 'Content-Type': 'application/json' })
      res.end(JSON.stringify({ message: 'File not found' }))
      return
    }
    
    const content = await readFile(fullPath)
    const mimeType = getMimeType(fullPath)
    
    res.writeHead(200, { 
      'Content-Type': mimeType,
      'Access-Control-Allow-Origin': '*',
      'Cache-Control': 'no-cache'
    })
    res.end(content)
    
  } catch (error) {
    console.error('Error serving file:', error)
    res.writeHead(500, { 'Content-Type': 'application/json' })
    res.end(JSON.stringify({ message: 'Internal Server Error', error: error.message }))
  }
})

async function handleApiRequest(req, res, reqPath) {
  res.setHeader('Content-Type', 'application/json')
  res.setHeader('Access-Control-Allow-Origin', '*')
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type')
  
  if (req.method === 'OPTIONS') {
    res.writeHead(200)
    res.end()
    return
  }
  
  try {
    if (reqPath === '/api/contacts' && req.method === 'GET') {
      const contacts = await getContacts()
      res.writeHead(200)
      res.end(JSON.stringify(contacts))
      
    } else if (reqPath === '/api/categories' && req.method === 'GET') {
      const categories = await getCategories()
      res.writeHead(200)
      res.end(JSON.stringify(categories))
      
    } else if (reqPath.startsWith('/api/icon/') && req.method === 'GET') {
      const iconPath = reqPath.replace('/api/icon/', '')
      const fullPath = path.join(DATA_DIR, iconPath)
      
      console.log(`[DEBUG] Icon request: ${reqPath}`)
      console.log(`[DEBUG] Icon path: ${iconPath}`)
      console.log(`[DEBUG] Full path: ${fullPath}`)
      console.log(`[DEBUG] Exists: ${existsSync(fullPath)}`)
      
      if (!existsSync(fullPath)) {
        res.writeHead(404)
        res.end(JSON.stringify({ message: 'Icon not found' }))
        return
      }
      
      const content = await readFile(fullPath)
      res.writeHead(200, { 'Content-Type': 'image/png' })
      res.end(content)
      
    } else if (reqPath.startsWith('/api/contacts/') && req.method === 'POST') {
      const parts = reqPath.split('/')
      const category = parts[3]
      const filename = parts[4]
      
      const data = await parseFormData(req)
      
      await saveContact(category, filename, {
        organization: data.organization,
        phones: data.phones,
        url: data.url,
        icon: data.icon
      })
      
      res.writeHead(201)
      res.end(JSON.stringify({ message: 'Created' }))
      
    } else if (reqPath.startsWith('/api/contacts/') && req.method === 'PUT') {
      const parts = reqPath.split('/')
      const category = parts[3]
      const filename = parts[4]
      
      const data = await parseFormData(req)
      
      await saveContact(category, filename, {
        organization: data.organization,
        phones: data.phones,
        url: data.url,
        icon: data.icon
      })
      
      res.writeHead(200)
      res.end(JSON.stringify({ message: 'Updated' }))
      
    } else if (reqPath.startsWith('/api/contacts/') && req.method === 'DELETE') {
      const parts = reqPath.split('/')
      const category = parts[3]
      const filename = parts[4]
      
      await deleteContact(category, filename)
      
      res.writeHead(200)
      res.end(JSON.stringify({ message: 'Deleted' }))
      
    } else {
      res.writeHead(404)
      res.end(JSON.stringify({ message: 'Not found' }))
    }
    
  } catch (error) {
    console.error('API Error:', error)
    res.writeHead(500)
    res.end(JSON.stringify({ message: 'Internal Server Error', error: error.message }))
  }
}

async function parseFormData(req) {
  return new Promise((resolve, reject) => {
    const busboy = Busboy({ headers: req.headers })
    const result = {
      organization: '',
      category: '',
      url: '',
      phones: [],
      icon: null
    }

    busboy.on('field', (name, value) => {
      if (name.startsWith('phones[')) {
        result.phones.push(value)
      } else if (name === 'organization') {
        result.organization = value
      } else if (name === 'category') {
        result.category = value
      } else if (name === 'url') {
        result.url = value || null
      }
    })

    busboy.on('file', (name, file, info) => {
      if (name === 'icon') {
        const chunks = []
        file.on('data', (chunk) => {
          chunks.push(chunk)
        })
        file.on('end', () => {
          result.icon = Buffer.concat(chunks)
        })
      } else {
        file.resume()
      }
    })

    busboy.on('finish', () => {
      resolve(result)
    })

    busboy.on('error', (err) => {
      reject(err)
    })

    req.pipe(busboy)
  })
}

function buildAdminFiles() {
  const templateDir = path.join(__dirname, './templates')
  const targetDir = PUBLIC_DIR
  
  if (!existsSync(targetDir)) {
    mkdirSync(targetDir, { recursive: true })
  }
  
  const files = ['admin.html', 'admin.css', 'admin.js']
  
  files.forEach(file => {
    const source = path.join(templateDir, file)
    const target = path.join(targetDir, file)
    
    if (existsSync(source)) {
      const content = readFileSync(source)
      writeFileSync(target, content)
    }
  })
  
  console.log('✅ 管理后台文件已构建')
}

import { readFileSync, writeFileSync } from 'node:fs'

buildAdminFiles()

server.listen(PORT, () => {
  console.log(`🚀 vCards 管理后台运行在: http://localhost:${PORT}`)
  console.log(`📁 数据目录: ${DATA_DIR}`)
  console.log('按 Ctrl+C 停止服务器')
})

process.on('SIGINT', () => {
  console.log('\n正在关闭服务器...')
  server.close(() => {
    console.log('服务器已关闭')
    process.exit(0)
  })
})

process.on('SIGTERM', () => {
  console.log('\n正在关闭服务器...')
  server.close(() => {
    console.log('服务器已关闭')
    process.exit(0)
  })
})