<template>
  <section v-if="station" class="page station-page" v-loading="map.loading">
    <div class="page-head">
      <div class="crumbs">
        <el-button text @click="router.push('/map')">地图</el-button>
        <el-button text @click="goWorkshop">{{ workshopName(form.workshopId) }}</el-button>
        <span class="crumb current">{{ station.name }}</span>
      </div>
      <div class="head-main">
        <div>
          <div class="eyebrow">站点详情</div>
          <h2 class="page-title">{{ station.name }}</h2>
          <p class="subline">名称、备注、目录保存在 MySQL，图片保存在 MinIO。</p>
        </div>
        <div class="button-row">
          <el-button @click="goWorkshop">返回车间</el-button>
        </div>
      </div>
    </div>

    <div class="station-layout">
      <section class="panel info-panel">
        <el-form label-position="top">
          <el-form-item label="站点名称">
            <el-input v-model="form.name" @change="saveProfile" />
          </el-form-item>
          <el-form-item label="车间">
            <el-select v-model="form.workshopId" style="width: 100%" @change="saveProfile">
              <el-option v-for="workshop in workshops" :key="workshop.id" :label="workshop.name" :value="workshop.id" />
            </el-select>
          </el-form-item>
          <el-form-item label="公里标">
            <el-input v-model="form.mileage" maxlength="64" @change="saveProfile" />
          </el-form-item>
          <div class="form-grid compact">
            <label>类型</label><div class="value">{{ station.color === 'blue' ? '已撤站' : '车站' }}</div>
            <label>图片</label><div class="value">{{ countImages(station.folders) }} 张</div>
          </div>
          <el-form-item label="备注">
            <el-input v-model="form.notes" type="textarea" :rows="8" @change="saveProfile" />
          </el-form-item>
        </el-form>
      </section>

      <div class="manager-grid">
        <section class="panel folder-panel">
          <div class="panel-head">
            <h3 class="panel-title">目录管理</h3>
            <el-button type="primary" @click="addRootFolder">添加一级目录</el-button>
          </div>
          <el-tree
            v-if="folderTree.length"
            class="folder-tree"
            :data="folderTree"
            node-key="id"
            default-expand-all
            highlight-current
            :current-node-key="selectedFolderId"
            :expand-on-click-node="false"
            @node-click="selectFolderNode"
          >
            <template #default="{ data }">
              <div class="folder-node-row" :class="{ selected: data.id === selectedFolderId }">
                <span class="folder-number">{{ data.number }}</span>
                <el-input
                  :ref="(el: unknown) => setFolderInputRef(data.id, el)"
                  v-model="data.folder.name"
                  @change="renameFolder(data.folder.id, data.folder.name)"
                />
                <span class="folder-count">{{ countImages([data.folder]) }}图{{ data.folder.children.length ? ` · ${data.folder.children.length}级` : '' }}</span>
                <el-button size="small" :disabled="folderDepth(data) >= 3" @click.stop="addChildFolder(data.folder.id)">下级</el-button>
                <el-button size="small" type="danger" plain :disabled="data.folder.children.length > 0 || data.folder.images.length > 0" @click.stop="deleteFolder(data.folder.id)">删除</el-button>
              </div>
            </template>
          </el-tree>
          <div v-else class="empty">请添加目录</div>
        </section>

        <section class="panel image-panel">
          <div class="panel-head">
            <div class="current-folder">
              <h3 class="panel-title">当前目录图片</h3>
              <div class="folder-path">{{ selectedFolderPath || '请选择目录' }}</div>
              <div class="meta">{{ selectedFolder ? '当前目录可添加图片' : '请选择目录' }}</div>
            </div>
            <div class="button-row">
              <el-button type="primary" :disabled="!selectedFolder" @click="imageInput?.click()">添加图片</el-button>
              <el-button type="danger" plain :disabled="!selectedFolderImages.length" @click="toggleDeleteImageMode">{{ deleteImageMode ? '完成删除' : '删除图片' }}</el-button>
            </div>
            <input ref="imageInput" class="file-input" type="file" multiple accept="image/*" @change="uploadImages" />
          </div>
          <div class="image-grid">
            <div v-for="image in selectedFolderImages" :key="image.id" class="photo">
              <el-image class="photo-preview" :src="image.url" :alt="image.name" fit="cover" lazy @load="rememberImageSize(image.id, $event)" @click="openImagePreview(imageIndex(image.id))" />
              <button v-if="deleteImageMode" class="photo-delete-button" title="删除图片" @click.stop="deleteImage(image.id)">×</button>
            </div>
            <div v-if="!selectedFolderImages.length" class="empty">{{ selectedFolder ? '暂无图片' : '请选择目录' }}</div>
          </div>
        </section>
      </div>
    </div>
  </section>
  <section v-else class="page"><div class="empty">站点不存在</div></section>
  <el-image-viewer
    v-if="previewVisible"
    :key="previewViewerKey"
    :url-list="previewImageUrls"
    :initial-index="previewIndex"
    :scale="previewScale"
    :zoom-rate="1.2"
    :max-scale="12"
    teleported
    @switch="switchImagePreview"
    @close="closeImagePreview"
  />
</template>

<script setup lang="ts">
import { ElMessage, ElMessageBox } from 'element-plus'
import { computed, nextTick, onMounted, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useMapStore } from '../stores/map'
import type { StationFolder } from '../types'
import { findNumberedFolderNode, numberedFolderTree, type NumberedFolderNode } from '../utils/folderTree'
import { imageViewerScale } from '../utils/imageViewerScale'
import { workshopName as resolveWorkshopName } from '../utils/workshopRoute'

const route = useRoute()
const router = useRouter()
const map = useMapStore()
const imageInput = ref<HTMLInputElement | null>(null)
const selectedFolderId = ref('')
const deleteImageMode = ref(false)
const previewVisible = ref(false)
const previewIndex = ref(0)
const imageSizes = reactive<Record<string, { width: number; height: number }>>({})
const previewViewport = reactive(currentViewport())
const folderInputs = new Map<string, { focus: () => void }>()
const form = reactive<{ name: string; notes: string; mileage: string; workshopId: number | null }>({ name: '', notes: '', mileage: '', workshopId: null })
const station = computed(() => map.stationById(String(route.params.id)))
const workshops = computed(() => map.workshops)

onMounted(async () => {
  await map.load()
  syncForm()
})

watch(station, syncForm)

function syncForm() {
  if (!station.value) return
  form.name = station.value.name
  form.notes = station.value.notes || ''
  form.mileage = station.value.mileage || ''
  form.workshopId = station.value.workshopId
  if (!selectedFolderId.value && station.value.folders[0]) selectedFolderId.value = station.value.folders[0].id
}

const folderTree = computed(() => numberedFolderTree(station.value?.folders || []))
const selectedRow = computed(() => findNumberedFolderNode(folderTree.value, selectedFolderId.value))
const selectedFolder = computed(() => selectedRow.value?.folder || null)
const selectedFolderPath = computed(() => selectedRow.value?.pathText || '')
const selectedFolderImages = computed(() => selectedFolder.value?.images || [])
const previewImageUrls = computed(() => selectedFolderImages.value.map((image) => image.url))
const previewImage = computed(() => selectedFolderImages.value[previewIndex.value] || null)
const previewScale = computed(() => imageViewerScale(previewImage.value ? imageSizes[previewImage.value.id] : null, previewViewport))
const previewViewerKey = computed(() => `${previewIndex.value}-${previewScale.value}`)

watch(selectedFolderId, () => {
  deleteImageMode.value = false
  closeImagePreview()
})
watch(selectedFolderImages, (images) => {
  if (!images.length) deleteImageMode.value = false
})

function countImages(folders: StationFolder[]): number {
  return folders.reduce((sum, folder) => sum + folder.images.length + countImages(folder.children), 0)
}

async function saveProfile() {
  if (!station.value) return
  await map.updateProfile(station.value.id, { name: form.name, notes: form.notes, mileage: form.mileage, workshopId: form.workshopId })
  ElMessage.success('已保存')
}

function workshopName(id: number | string | null | undefined) {
  return resolveWorkshopName(workshops.value, id)
}

function goWorkshop() {
  if (form.workshopId != null) router.push(`/workshops/${form.workshopId}`)
}

async function addRootFolder() {
  if (!station.value) return
  const folder = await map.addFolder(station.value.id, null)
  await selectAndFocusFolder(folder.id)
}

async function addChildFolder(parentId: string) {
  if (!station.value) return
  const folder = await map.addFolder(station.value.id, parentId)
  await selectAndFocusFolder(folder.id)
}

async function renameFolder(folderId: string, name: string) {
  await map.renameFolder(folderId, name)
}

async function deleteFolder(folderId: string) {
  try {
    await ElMessageBox.confirm('确定删除这个目录吗？删除后不可恢复。', '删除目录', {
      confirmButtonText: '确认删除',
      cancelButtonText: '取消',
      type: 'warning'
    })
  } catch {
    return
  }
  await map.deleteFolder(folderId)
  if (selectedFolderId.value === folderId) selectedFolderId.value = ''
  ElMessage.success('已删除目录')
}

async function uploadImages(event: Event) {
  const files = (event.target as HTMLInputElement).files
  if (!station.value || !selectedFolder.value || !files?.length) return
  await map.uploadImages(station.value.id, selectedFolder.value.id, files)
  ;(event.target as HTMLInputElement).value = ''
  ElMessage.success('已上传图片')
}

async function deleteImage(imageId: string) {
  try {
    await ElMessageBox.confirm('确定删除这张图片吗？删除后不可恢复。', '删除图片', {
      confirmButtonText: '确认删除',
      cancelButtonText: '取消',
      type: 'warning'
    })
  } catch {
    return
  }
  await map.deleteImage(imageId)
  ElMessage.success('已删除图片')
}

function selectFolderNode(data: NumberedFolderNode) {
  selectedFolderId.value = data.id
}

function toggleDeleteImageMode() {
  if (!selectedFolderImages.value.length) return
  deleteImageMode.value = !deleteImageMode.value
}

function folderDepth(data: NumberedFolderNode) {
  return data.number.split('.').length
}

function setFolderInputRef(id: string, el: unknown) {
  const input = el as { focus?: () => void } | null
  if (input?.focus) folderInputs.set(id, { focus: input.focus.bind(input) })
  else folderInputs.delete(id)
}

async function selectAndFocusFolder(folderId: string) {
  selectedFolderId.value = folderId
  await nextTick()
  folderInputs.get(folderId)?.focus()
}

function openImagePreview(index: number) {
  updatePreviewViewport()
  previewIndex.value = Math.min(Math.max(0, index), Math.max(0, selectedFolderImages.value.length - 1))
  previewVisible.value = true
}

function switchImagePreview(index: number) {
  updatePreviewViewport()
  previewIndex.value = Math.max(0, index)
}

function closeImagePreview() {
  previewVisible.value = false
}

function rememberImageSize(imageId: string, event: Event) {
  const target = event.target as HTMLImageElement | null
  if (!target?.naturalWidth || !target?.naturalHeight) return
  imageSizes[imageId] = { width: target.naturalWidth, height: target.naturalHeight }
}

function currentViewport() {
  if (typeof window === 'undefined') return { width: 0, height: 0 }
  return { width: window.innerWidth, height: window.innerHeight }
}

function updatePreviewViewport() {
  const viewport = currentViewport()
  previewViewport.width = viewport.width
  previewViewport.height = viewport.height
}

function imageIndex(imageId: string) {
  return Math.max(0, selectedFolderImages.value.findIndex((image) => image.id === imageId))
}
</script>
