import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'
import { deleteAsync } from 'del'
import through2 from 'through2'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

import gulp from 'gulp'
import zip from 'gulp-zip'
import concat from 'gulp-concat'
import rename from 'gulp-rename'
import concatFolders from 'gulp-concat-folders'

import plugin_vcard from './plugins/vcard.js'
import plugin_vcard_ext from './plugins/vcard-ext.js'
import yaml from 'js-yaml'

const generator = () => {
  return gulp.src('data/*/*.yaml')
    .pipe(through2.obj(plugin_vcard))
    .pipe(rename({ extname: '.vcf' }))
    .pipe(gulp.dest('./temp'))
}

const generator_ext = () => {
  return gulp.src('data/*/*.yaml')
    .pipe(through2.obj(plugin_vcard_ext))
    .pipe(rename({ extname: '.vcf' }))
    .pipe(gulp.dest('./temp'))
}

const archive = () => {
  return gulp.src('temp/**')
    .pipe(zip('archive.zip'))
    .pipe(gulp.dest('./public'))
}

const distSummary = () => {
  return gulp.src('temp/汇总/全部.vcf')
    .pipe(rename('汇总.vcf'))
    .pipe(gulp.dest('./public'))
}

const combine = () => {
  return gulp.src('temp/*/*.vcf')
    .pipe(concatFolders('汇总'))
    .pipe(rename({ extname: '.all.vcf' }))
    .pipe(gulp.dest('./temp'))
}

const allinone = () => {
  return gulp.src('temp/汇总/*.all.vcf')
    .pipe(concat('全部.vcf'))
    .pipe(gulp.dest('./temp/汇总'))
}

const clean = () => {
  return deleteAsync([
    'public',
    'temp'
  ])
}

const cleanWeb = () => {
  return deleteAsync([
    'public-web'
  ])
}

// 网页版本构建任务
const webBuild = async () => {
  try {
    const { globby } = await import('globby')
    const vcardsData = []
    
    // 读取所有 YAML 文件
    const yamlFiles = await globby('data/*/*.yaml')
    
    for (const filePath of yamlFiles) {
      const content = fs.readFileSync(filePath, 'utf8')
      const data = yaml.load(content)
      
      if (data && data.basic) {
        const fileName = path.basename(filePath, '.yaml')
        const categoryPath = path.dirname(filePath)
        const category = path.basename(categoryPath)
        
        vcardsData.push({
          organization: data.basic.organization,
          phones: data.basic.cellPhone || [],
          url: data.basic.url || null,
          emails: data.basic.workEmail || [],
          category: category,
          filename: fileName
        })
      }
    }
    
    console.log(`正在构建网页版本，共 ${vcardsData.length} 个联系人...`)
    
    // 构建网页
    await buildWebsite(vcardsData)
    
    console.log('网页版本构建完成，输出到: ./public-web')
  } catch (error) {
    console.error('构建网页版本时出错:', error)
    throw error
  }
}

// 构建网站函数
async function buildWebsite(vcardsData) {
  const outputDir = './public-web'
  const templateDir = './src/templates'
  
  // 确保输出目录存在
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true })
  }
  
  // 创建子目录
  const iconsDir = path.join(outputDir, 'icons')
  const vcfDir = path.join(outputDir, 'vcf')
  
  if (!fs.existsSync(iconsDir)) {
    fs.mkdirSync(iconsDir, { recursive: true })
  }
  if (!fs.existsSync(vcfDir)) {
    fs.mkdirSync(vcfDir, { recursive: true })
  }
  
  // 复制模板文件并注入数据
  copyTemplateFiles(templateDir, outputDir, vcardsData)
  
  // 复制图标文件
  copyIconFiles(iconsDir, vcardsData)
  
  // 复制 VCF 文件（从临时目录）
  copyVcfFiles(vcfDir, vcardsData)
}

/**
 * 复制模板文件并注入数据
 */
function copyTemplateFiles(templateDir, outputDir, vcardsData) {
  // 复制 HTML 文件并注入数据
  const htmlTemplate = fs.readFileSync(path.join(templateDir, 'index.html'), 'utf8')
  const jsTemplate = fs.readFileSync(path.join(templateDir, 'app.js'), 'utf8')
  
  // 生成数据注入脚本
  const dataScript = `window.VCARDS_DATA = ${JSON.stringify(vcardsData, null, 2)};`
  
  // 将数据脚本和应用脚本合并
  const finalJs = dataScript + '\n\n' + jsTemplate
  
  // 写入文件
  fs.writeFileSync(path.join(outputDir, 'index.html'), htmlTemplate)
  fs.writeFileSync(path.join(outputDir, 'app.js'), finalJs)
  fs.copyFileSync(path.join(templateDir, 'styles.css'), path.join(outputDir, 'styles.css'))
}

/**
 * 复制图标文件
 */
function copyIconFiles(iconsDir, vcardsData) {
  const processedCategories = new Set()
  
  vcardsData.forEach(item => {
    const categoryDir = path.join(iconsDir, item.category)
    
    // 为每个分类创建目录
    if (!processedCategories.has(item.category)) {
      if (!fs.existsSync(categoryDir)) {
        fs.mkdirSync(categoryDir, { recursive: true })
      }
      processedCategories.add(item.category)
    }
    
    // 复制图标文件
    const sourcePath = path.join('data', item.category, `${item.filename}.png`)
    const targetPath = path.join(categoryDir, `${item.filename}.png`)
    
    if (fs.existsSync(sourcePath)) {
      fs.copyFileSync(sourcePath, targetPath)
    } else {
      console.warn(`图标文件不存在: ${sourcePath}`)
    }
  })
}

/**
 * 复制 VCF 文件
 */
function copyVcfFiles(vcfDir, vcardsData) {
  const processedCategories = new Set()
  
  vcardsData.forEach(item => {
    const categoryDir = path.join(vcfDir, item.category)
    
    // 为每个分类创建目录
    if (!processedCategories.has(item.category)) {
      if (!fs.existsSync(categoryDir)) {
        fs.mkdirSync(categoryDir, { recursive: true })
      }
      processedCategories.add(item.category)
    }
    
    // 复制 VCF 文件
    const sourcePath = path.join('temp', item.category, `${item.filename}.vcf`)
    const targetPath = path.join(categoryDir, `${item.filename}.vcf`)
    
    if (fs.existsSync(sourcePath)) {
      fs.copyFileSync(sourcePath, targetPath)
    } else {
      console.warn(`VCF 文件不存在: ${sourcePath}`)
    }
  })
}

const createRadicale = () => {
  let folders = fs.readdirSync('temp')
    .filter(function(f) {
      return fs.statSync(path.join('temp', f)).isDirectory();
    })
  folders.map(function(folder){
    const fileCount = fs.readdirSync(path.join('temp', folder))
      .filter(file => file.endsWith('.vcf'))
      .length;
    fs.writeFileSync(
      path.join('temp', folder, '/.Radicale.props'), 
      `{"D:displayname": "${folder}(${fileCount})", "tag": "VADDRESSBOOK"}`
    )
  })
  return gulp.src('temp/**', {})
}

const cleanRadicale = () => {
  return deleteAsync([
    'radicale'
  ], {force: true})
}

const distRadicale = () => {
  return gulp.src('temp/**', {dot: true})
    .pipe(gulp.dest('./radicale/ios'))
}

// 新增：所有 vcf 和 props 放到 radicale/macos/全部/
const distRadicaleMacos = (done) => {
  const allDir = './radicale/macos/全部';
  if (!fs.existsSync(allDir)) fs.mkdirSync(allDir, {recursive: true});
  let totalCount = 0;
  // 1. 复制所有 vcf 文件到 radicale/macos/全部/
  const tempFolders = fs.readdirSync('temp').filter(f => fs.statSync(path.join('temp', f)).isDirectory());
  tempFolders.forEach(folder => {
    const folderPath = path.join('temp', folder);
    const vcfFiles = fs.readdirSync(folderPath).filter(f => f.endsWith('.vcf'));
    vcfFiles.forEach(file => {
      fs.copyFileSync(path.join(folderPath, file), path.join(allDir, file));
    });
    totalCount += vcfFiles.length;
  });
  // 2. 只在 radicale/macos/全部/ 下生成一个 props 文件
  fs.writeFileSync(
    path.join(allDir, '.Radicale.props'),
    `{"D:displayname": "全部(${totalCount})", "tag": "VADDRESSBOOK"}`
  );
  done();
}

const build = gulp.series(clean, generator, combine, allinone, distSummary, archive)
const radicale = gulp.series(
  clean,
  generator_ext,
  createRadicale,
  cleanRadicale,
  gulp.parallel(distRadicale, distRadicaleMacos)
)

// 网页版本完整构建流程
const buildWeb = gulp.series(cleanWeb, generator, webBuild)

// ==================== 增量构建功能 ====================
import crypto from 'crypto'

const BUILD_HASH_FILE = path.join(__dirname, '.build-hash')

async function computeFileHash(filePath) {
  const content = await fs.promises.readFile(filePath)
  return crypto.createHash('sha1').update(content).digest('hex')
}

async function readBuildHash() {
  if (fs.existsSync(BUILD_HASH_FILE)) {
    try {
      const content = await fs.promises.readFile(BUILD_HASH_FILE, 'utf8')
      return JSON.parse(content)
    } catch {
      return { files: {}, categories: {} }
    }
  }
  return { files: {}, categories: {} }
}

function saveBuildHash(hashData) {
  fs.writeFileSync(BUILD_HASH_FILE, JSON.stringify(hashData, null, 2))
}

async function scanDataDirectory() {
  const files = {}
  const categories = {}
  
  function scan(dir, category = null) {
    const entries = fs.readdirSync(dir, { withFileTypes: true })
    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name)
      if (entry.isDirectory()) {
        categories[entry.name] = []
        scan(fullPath, entry.name)
      } else if (entry.isFile()) {
        const ext = path.extname(entry.name).toLowerCase()
        if (ext === '.yaml' || ext === '.png') {
          files[fullPath] = null
          if (category) {
            const baseName = path.basename(entry.name, ext)
            if (!categories[category].includes(baseName)) {
              categories[category].push(baseName)
            }
          }
        }
      }
    }
  }
  
  scan('./data')
  
  for (const filePath of Object.keys(files)) {
    files[filePath] = await computeFileHash(filePath)
  }
  
  return { files, categories }
}

async function detectChanges() {
  const lastBuild = await readBuildHash()
  const current = await scanDataDirectory()
  
  const changes = { new: [], modified: [], deleted: [] }
  const affectedCategories = new Set()
  
  const dataDir = path.resolve('./data')
  for (const [filePath, currentHash] of Object.entries(current.files)) {
    const relPath = path.relative(dataDir, filePath)
    const parts = relPath.split(path.sep)
    const category = parts[0]
    
    if (!lastBuild.files[filePath]) {
      changes.new.push({
        path: relPath,
        fullPath: filePath,
        category,
        filename: path.basename(filePath)
      })
      affectedCategories.add(category)
    } else if (lastBuild.files[filePath] !== currentHash) {
      changes.modified.push({
        path: relPath,
        fullPath: filePath,
        category,
        filename: path.basename(filePath)
      })
      affectedCategories.add(category)
    }
  }
  
  for (const [filePath] of Object.entries(lastBuild.files)) {
    if (!current.files[filePath]) {
      const relPath = path.relative(dataDir, filePath)
      const parts = relPath.split(path.sep)
      const category = parts[0]
      
      changes.deleted.push({
        path: relPath,
        fullPath: filePath,
        category,
        filename: path.basename(filePath)
      })
      affectedCategories.add(category)
    }
  }
  
  return {
    changes,
    affectedCategories: Array.from(affectedCategories),
    current
  }
}

function generateChangelog(changes, timestamp) {
  const changelog = []
  changelog.push('# 增量构建变更摘要')
  changelog.push('')
  changelog.push('## 基本信息')
  changelog.push(`- 构建时间: ${new Date(timestamp).toLocaleString('zh-CN')}`)
  changelog.push('- 变更类型: 增量构建')
  changelog.push('')
  
  const newCount = changes.new.length
  const modCount = changes.modified.length
  const delCount = changes.deleted.length
  
  changelog.push('## 变更统计')
  changelog.push('| 类型 | 数量 |')
  changelog.push('|------|------|')
  changelog.push(`| 新增 | ${newCount} |`)
  changelog.push(`| 修改 | ${modCount} |`)
  changelog.push(`| 删除 | ${delCount} |`)
  
  if (newCount > 0) {
    changelog.push('')
    changelog.push('## 新增文件')
    for (const change of changes.new) {
      changelog.push(`- 📁 ${change.path}`)
    }
  }
  
  if (modCount > 0) {
    changelog.push('')
    changelog.push('## 修改文件')
    for (const change of changes.modified) {
      changelog.push(`- 🔄 ${change.path}`)
    }
  }
  
  if (delCount > 0) {
    changelog.push('')
    changelog.push('## 删除文件')
    for (const change of changes.deleted) {
      changelog.push(`- 🗑️ ${change.path}`)
    }
  }
  
  return changelog.join('\n')
}

function generateChangeRecord(changes, timestamp, affectedCategories) {
  return JSON.stringify({
    buildTime: new Date(timestamp).toISOString(),
    buildType: 'incremental',
    summary: {
      new: changes.new.length,
      modified: changes.modified.length,
      deleted: changes.deleted.length
    },
    changes: [
      ...changes.new.map(c => ({ ...c, type: 'new' })),
      ...changes.modified.map(c => ({ ...c, type: 'modified' })),
      ...changes.deleted.map(c => ({ ...c, type: 'deleted' }))
    ],
    affectedCategories
  }, null, 2)
}

const buildIncremental = async () => {
  const { changes, affectedCategories, current } = await detectChanges()
  const timestamp = Date.now()
  const timestampStr = new Date(timestamp).toISOString().replace(/[:.]/g, '-').slice(0, 19)
  
  if (changes.new.length === 0 && changes.modified.length === 0 && changes.deleted.length === 0) {
    console.log('✅ 无变更，跳过增量构建')
    return
  }
  
  console.log(`🔄 检测到变更: 新增${changes.new.length}个, 修改${changes.modified.length}个, 删除${changes.deleted.length}个`)
  console.log(`📁 受影响分类: ${affectedCategories.join(', ')}`)
  
  const tempIncDir = './temp/incremental'
  if (!fs.existsSync(tempIncDir)) {
    fs.mkdirSync(tempIncDir, { recursive: true })
  }
  
  const changelog = generateChangelog(changes, timestamp)
  const changeRecord = generateChangeRecord(changes, timestamp, affectedCategories)
  
  fs.writeFileSync(path.join(tempIncDir, 'CHANGELOG.md'), changelog)
  fs.writeFileSync(path.join(tempIncDir, '变更记录.json'), changeRecord)
  
  const newDir = path.join(tempIncDir, '新增')
  const modDir = path.join(tempIncDir, '修改')
  const delDir = path.join(tempIncDir, '删除')
  const summaryDir = path.join(tempIncDir, '汇总')
  fs.mkdirSync(newDir, { recursive: true })
  fs.mkdirSync(modDir, { recursive: true })
  fs.mkdirSync(delDir, { recursive: true })
  fs.mkdirSync(summaryDir, { recursive: true })
  
  const categoryVcfMap = {}
  
  for (const category of affectedCategories) {
    categoryVcfMap[category] = []
    const categoryDir = path.join('./data', category)
    const yamlFiles = fs.readdirSync(categoryDir).filter(f => f.endsWith('.yaml'))
    
    for (const yamlFile of yamlFiles) {
      const yamlPath = path.join(categoryDir, yamlFile)
      const baseName = path.basename(yamlFile, '.yaml')
      
      const isNew = changes.new.some(c => c.filename === `${baseName}.yaml` || c.filename === `${baseName}.png`)
      const isModified = changes.modified.some(c => c.filename === `${baseName}.yaml` || c.filename === `${baseName}.png`)
      const isDeleted = changes.deleted.some(c => c.filename === `${baseName}.yaml` || c.filename === `${baseName}.png`)
      
      if (!isNew && !isModified && !isDeleted) {
        continue
      }
      
      const content = fs.readFileSync(yamlPath, 'utf8')
      const data = yaml.load(content)
      
      if (data && data.basic) {
        const vcfContent = await new Promise((resolve) => {
          plugin_vcard({ path: yamlPath, contents: content }, null, (err, result) => {
            resolve(err ? null : result.contents.toString())
          })
        })
        
        if (vcfContent) {
          categoryVcfMap[category].push(vcfContent)
          
          let targetDir
          if (isDeleted) {
            targetDir = delDir
          } else if (isNew) {
            targetDir = newDir
          } else {
            targetDir = modDir
          }
          
          const categoryTargetDir = path.join(targetDir, category)
          if (!fs.existsSync(categoryTargetDir)) {
            fs.mkdirSync(categoryTargetDir, { recursive: true })
          }
          
          if (isDeleted) {
            const delMarker = JSON.stringify({
              deletedAt: new Date(timestamp).toISOString(),
              originalPath: `${category}/${baseName}.yaml`,
              category,
              filename: baseName
            }, null, 2)
            fs.writeFileSync(path.join(categoryTargetDir, `${baseName}.vcf.del`), delMarker)
          } else {
            fs.writeFileSync(path.join(categoryTargetDir, `${baseName}.vcf`), vcfContent)
          }
        }
      }
    }
    
    if (categoryVcfMap[category].length > 0) {
      const allVcfContent = categoryVcfMap[category].join('\n')
      fs.writeFileSync(path.join(summaryDir, `${category}.all.vcf`), allVcfContent)
    }
  }
  
  const zipName = `archive-incremental-${timestampStr}.zip`
  return new Promise((resolve, reject) => {
    gulp.src(`${tempIncDir}/**/*`)
      .pipe(zip(zipName))
      .pipe(gulp.dest('./public'))
      .on('end', () => {
        console.log(`📦 增量包已生成: ${zipName}`)
        saveBuildHash({
          timestamp: new Date(timestamp).toISOString(),
          files: current.files,
          categories: current.categories
        })
        resolve()
      })
      .on('error', reject)
  })
}

const cleanBuildCache = (done) => {
  if (fs.existsSync(BUILD_HASH_FILE)) {
    fs.unlinkSync(BUILD_HASH_FILE)
    console.log('🗑️ 构建缓存已清理')
  }
  done()
}

export {
  generator,
  combine,
  allinone,
  archive,
  distSummary,
  build,
  radicale,
  buildWeb,
  buildIncremental,
  cleanBuildCache
}