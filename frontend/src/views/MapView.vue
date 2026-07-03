<template>
  <section class="page map-page" v-loading="map.loading">
    <div class="page-head">
      <div class="head-main">
        <div>
          <div class="eyebrow">整图总览</div>
          <h2 class="page-title">{{ currentMap?.name || '地图' }}</h2>
          <p class="subline">站点信息只保存一份；同一个站点可以在当前背景图上放置多个组件。</p>
        </div>
        <div class="inline-meta">
          <span class="badge">{{ filteredMarkers.length }}/{{ currentMap?.markers.length || 0 }} 个组件</span>
          <span class="badge">{{ totalImages }} 张图片</span>
        </div>
      </div>
      <div class="workshop-strip">
        <button v-for="workshop in workshops" :key="workshop.id" class="workshop-card" :style="{ '--workshop-color': workshop.color }" @click="router.push(workshopPath(workshop))">
          <strong>{{ workshop.name }}</strong>
          <span>{{ workshopStats(workshop.id).total }} 站 · {{ workshopStats(workshop.id).markers }} 组件</span>
        </button>
      </div>
    </div>

    <section class="panel map-panel">
      <div class="map-toolbar">
        <div class="tool-row">
          <el-select v-model="selectedMapId" class="select-field" placeholder="选择地图" @change="changeMap">
            <el-option v-for="item in map.maps" :key="item.id" :label="item.name" :value="item.id" />
          </el-select>
          <el-input v-model="query" class="search-field" placeholder="搜索站名、里程、车间" clearable />
          <el-select v-model="workshopFilter" class="select-field" aria-label="车间筛选">
            <el-option label="全部车间" value="all" />
            <el-option v-for="workshop in workshops" :key="workshop.id" :label="workshop.name" :value="workshop.id" />
          </el-select>
          <el-radio-group v-model="colorFilter">
            <el-radio-button label="all">全部</el-radio-button>
            <el-radio-button label="red">车站</el-radio-button>
            <el-radio-button label="blue">已撤站</el-radio-button>
          </el-radio-group>
        </div>
        <div class="tool-row">
          <el-button @click="zoomAt(1 / 1.18)">缩小</el-button>
          <el-button @click="zoomAt(1.18)">放大</el-button>
          <el-button @click="fitToViewport">适应整图</el-button>
          <el-button @click="openOriginalPdf">查看原始 PDF</el-button>
          <template v-if="auth.user?.isSuperAdmin">
            <el-button @click="pdfInput?.click()">上传 PDF</el-button>
            <el-button :type="editMode ? 'primary' : 'default'" @click="toggleEdit">{{ editMode ? '完成编辑' : '编辑布局' }}</el-button>
            <input ref="pdfInput" class="file-input" type="file" accept="application/pdf,.pdf" @change="uploadPdf" />
          </template>
        </div>
      </div>

      <div class="map-editor-layout" :class="{ editing: editMode }">
        <aside v-if="editMode" class="marker-palette">
          <h3 class="panel-title">新增按钮</h3>
          <p class="palette-hint">把这个黑色按钮拖到 PDF 上，再在下方选择它绑定的车站。</p>
          <div class="new-marker-drag" draggable="true" @dragstart="startNewMarkerDrag">
            <span class="new-marker-dot"></span>
            <strong>新增站点按钮</strong>
            <small>拖到地图任意位置</small>
          </div>
          <div v-if="selectedMarker || draftMarker" class="marker-form">
            <h3 class="panel-title">{{ draftMarker ? '新增按钮配置' : '选中按钮配置' }}</h3>
            <el-select v-model="selectedMarkerStationId" filterable placeholder="请选择车站" style="width: 100%">
              <el-option v-for="station in map.stations" :key="station.id" :label="station.name" :value="station.id" />
            </el-select>
            <el-input-number v-model="selectedMarkerSize" :min="3" :max="18" :step="0.2" style="width: 100%; margin-top: 8px" />
            <div class="button-row" style="margin-top: 8px">
              <el-button type="primary" :disabled="!selectedMarkerStationId" @click="saveSelectedMarker">{{ draftMarker ? '保存新增按钮' : '保存按钮' }}</el-button>
              <el-button type="danger" plain @click="deleteSelectedMarker">{{ draftMarker ? '取消' : '删除按钮' }}</el-button>
            </div>
          </div>
        </aside>

        <div
          ref="viewport"
          class="viewport"
          @wheel.prevent="onWheel"
          @dragover.prevent
          @drop.prevent="dropNewMarker"
          @pointerdown="startPan"
          @pointermove="movePointer"
          @pointerup="stopPointer"
          @pointercancel="stopPointer"
        >
          <div v-if="currentMap" class="map-canvas" :style="canvasStyle">
            <img class="base-map" :src="currentMap.backgroundUrl" :style="baseMapStyle" alt="地图背景" />
            <button
              v-for="marker in currentMap.markers"
              :key="marker.id"
              class="hotspot marker-hotspot"
              :class="{ hidden: !visibleMarkerIds.has(marker.id), selected: selectedMarkerId === marker.id }"
              :style="markerStyle(marker)"
              :title="marker.station.name"
              @click.stop="clickMarker(marker)"
              @pointerdown.stop="startMarkerDrag(marker, $event)"
              @pointerover="showHover(marker, $event)"
              @pointermove="moveHover($event)"
              @pointerout="hoverMarker = null"
            />
            <button
              v-if="draftMarker"
              class="hotspot marker-hotspot selected draft-marker"
              :style="markerStyle({ ...draftMarker, size: selectedMarkerSize })"
              title="新按钮"
            />
          </div>
        </div>
      </div>
    </section>

    <div v-if="hoverMarker" class="hover-card show" :style="hoverStyle">
      <p class="hover-name">{{ hoverMarker.station.name }}</p>
      <div class="hover-meta">{{ colorLabel(hoverMarker.station.color) }} · {{ workshopName(hoverMarker.station.workshopId) }}</div>
      <div class="hover-meta">里程：{{ hoverMarker.station.mileage || '未匹配' }}</div>
      <div class="hover-meta">图片：{{ countImages(hoverMarker.station.folders) }} 张</div>
      <div v-if="firstImages(hoverMarker.station).length" class="hover-photos">
        <img v-for="image in firstImages(hoverMarker.station)" :key="image.id" :src="image.url" alt="" />
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { ElMessage, ElMessageBox } from 'element-plus'
import { computed, nextTick, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { useMapStore } from '../stores/map'
import type { MapMarker, Station, StationFolder, StationImage } from '../types'
import { createMarkerDraft } from '../utils/markerDraft'
import { DEFAULT_MARKER_SIZE, markerCssVars } from '../utils/markerStyle'
import { stationDetailPath } from '../utils/stationRoute'
import { workshopName as resolveWorkshopName, workshopPath } from '../utils/workshopRoute'

type DraftMarker = { x: number; y: number; size: number }

const map = useMapStore()
const auth = useAuthStore()
const router = useRouter()
const viewport = ref<HTMLElement | null>(null)
const pdfInput = ref<HTMLInputElement | null>(null)
const selectedMapId = ref('')
const query = ref('')
const workshopFilter = ref<number | 'all'>('all')
const colorFilter = ref('all')
const editMode = ref(false)
const selectedMarkerId = ref('')
const selectedMarkerStationId = ref('')
const selectedMarkerSize = ref(DEFAULT_MARKER_SIZE)
const scale = ref(1)
const panX = ref(0)
const panY = ref(0)
const panDrag = ref<{ x: number; y: number; panX: number; panY: number } | null>(null)
const markerDrag = ref<{ id: string; moved: boolean } | null>(null)
const draftMarker = ref<DraftMarker | null>(null)
const hoverMarker = ref<MapMarker | null>(null)
const hoverX = ref(0)
const hoverY = ref(0)

onMounted(async () => {
  await map.load()
  selectedMapId.value = map.currentMap?.id || ''
  await nextTick()
  fitToViewport()
})

watch(() => map.currentMap?.id, async (id) => {
  if (id) selectedMapId.value = id
  selectedMarkerId.value = ''
  draftMarker.value = null
  await nextTick()
  fitToViewport()
})

const currentMap = computed(() => map.currentMap)
const workshops = computed(() => map.workshops)
const totalImages = computed(() => map.stations.reduce((sum, station) => sum + countImages(station.folders), 0))
const filteredMarkers = computed(() => {
  const text = query.value.trim().toLowerCase()
  return (currentMap.value?.markers || []).filter((marker) => {
    const station = marker.station
    const colorOk = colorFilter.value === 'all' || station.color === colorFilter.value
    const workshopOk = workshopFilter.value === 'all' || station.workshopId === workshopFilter.value
    const haystack = `${station.name} ${station.autoName} ${station.mileage} ${workshopName(station.workshopId)}`.toLowerCase()
    return colorOk && workshopOk && (!text || haystack.includes(text))
  })
})
const visibleMarkerIds = computed(() => new Set(filteredMarkers.value.map((marker) => marker.id)))
const canvasStyle = computed(() => ({ transform: `translate(${panX.value}px, ${panY.value}px) scale(${scale.value})`, width: `${currentMap.value?.width || 1191}px`, height: `${currentMap.value?.height || 842}px` }))
const baseMapStyle = computed(() => ({ width: `${currentMap.value?.width || 1191}px`, height: `${currentMap.value?.height || 842}px` }))
const hoverStyle = computed(() => ({ left: `${hoverX.value}px`, top: `${hoverY.value}px` }))
const selectedMarker = computed(() => currentMap.value?.markers.find((marker) => marker.id === selectedMarkerId.value) || null)

function workshopName(id: number | string | null | undefined) {
  return resolveWorkshopName(workshops.value, id)
}

function workshopStats(id: number) {
  const stations = map.stations.filter((station) => station.workshopId === id)
  const stationIds = new Set(stations.map((station) => station.id))
  const markers = currentMap.value?.markers.filter((marker) => stationIds.has(marker.station.id)).length || 0
  return { total: stations.length, markers }
}

function countImages(folders: StationFolder[]): number {
  return folders.reduce((sum, folder) => sum + folder.images.length + countImages(folder.children), 0)
}

function firstImages(station: Station) {
  const result: StationImage[] = []
  const walk = (folders: StationFolder[]) => {
    for (const folder of folders) {
      for (const image of folder.images) if (result.length < 3) result.push(image)
      if (result.length >= 3) return
      walk(folder.children)
    }
  }
  walk(station.folders)
  return result
}

function colorLabel(color: string) {
  return color === 'blue' ? '已撤站' : '车站'
}

function markerStyle(marker: { x: number; y: number; size?: number }) {
  return markerCssVars(marker)
}

async function changeMap(value: string) {
  await map.loadMap(value)
}

function toggleEdit() {
  editMode.value = !editMode.value
  selectedMarkerId.value = ''
  draftMarker.value = null
}

async function uploadPdf(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return
  const name = await ElMessageBox.prompt('请输入地图名称', '上传背景 PDF', { inputValue: file.name.replace(/\.pdf$/i, '') }).then((result) => result.value).catch(() => '')
  if (!name) return
  await map.createMap(name, file)
  input.value = ''
  ElMessage.success('已创建新地图')
}

function startNewMarkerDrag(event: DragEvent) {
  event.dataTransfer?.setData('new-marker', '1')
  if (event.dataTransfer) event.dataTransfer.effectAllowed = 'copy'
}

function dropNewMarker(event: DragEvent) {
  if (!editMode.value || !currentMap.value) return
  if (event.dataTransfer?.getData('new-marker') !== '1') return
  const point = localPoint(event.clientX, event.clientY)
  const draft = createMarkerDraft(point)
  draftMarker.value = draft.marker
  selectedMarkerId.value = ''
  selectedMarkerStationId.value = draft.stationId
  selectedMarkerSize.value = draft.size
}

function clickMarker(marker: MapMarker) {
  if (editMode.value) {
    draftMarker.value = null
    selectedMarkerId.value = marker.id
    selectedMarkerStationId.value = marker.station.id
    selectedMarkerSize.value = marker.size || DEFAULT_MARKER_SIZE
    return
  }
  router.push(stationDetailPath(marker.station))
}

function startMarkerDrag(marker: MapMarker, event: PointerEvent) {
  if (!editMode.value) return
  draftMarker.value = null
  selectedMarkerId.value = marker.id
  selectedMarkerStationId.value = marker.station.id
  selectedMarkerSize.value = marker.size || DEFAULT_MARKER_SIZE
  markerDrag.value = { id: marker.id, moved: false }
  ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
}

async function saveSelectedMarker() {
  if (!currentMap.value) return
  if (!selectedMarkerStationId.value) {
    ElMessage.warning('请选择按钮对应的车站')
    return
  }
  if (draftMarker.value) {
    await map.createMarker(currentMap.value.id, {
      stationId: selectedMarkerStationId.value,
      x: draftMarker.value.x,
      y: draftMarker.value.y,
      size: selectedMarkerSize.value
    })
    draftMarker.value = null
    ElMessage.success('已新增按钮')
    return
  }
  if (!selectedMarker.value) return
  await map.updateMarker(currentMap.value.id, selectedMarker.value.id, {
    stationId: selectedMarkerStationId.value,
    x: selectedMarker.value.x,
    y: selectedMarker.value.y,
    size: selectedMarkerSize.value
  })
  ElMessage.success('已保存组件')
}

async function deleteSelectedMarker() {
  if (draftMarker.value) {
    draftMarker.value = null
    return
  }
  if (!currentMap.value || !selectedMarker.value) return
  await map.deleteMarker(currentMap.value.id, selectedMarker.value.id)
  selectedMarkerId.value = ''
}

function fitToViewport() {
  const rect = viewport.value?.getBoundingClientRect()
  if (!rect || !currentMap.value) return
  scale.value = Math.min((rect.width - 40) / currentMap.value.width, (rect.height - 40) / currentMap.value.height)
  scale.value = Math.min(2.8, Math.max(0.1, scale.value))
  panX.value = (rect.width - currentMap.value.width * scale.value) / 2
  panY.value = (rect.height - currentMap.value.height * scale.value) / 2
}

function openOriginalPdf() {
  window.open('/assets/original-map.pdf', '_blank', 'noopener')
}

function zoomAt(multiplier: number, event?: WheelEvent) {
  const rect = viewport.value?.getBoundingClientRect()
  if (!rect) return
  const pointX = event ? event.clientX : rect.left + rect.width / 2
  const pointY = event ? event.clientY : rect.top + rect.height / 2
  const localX = (pointX - rect.left - panX.value) / scale.value
  const localY = (pointY - rect.top - panY.value) / scale.value
  const nextScale = Math.min(8, Math.max(0.1, scale.value * multiplier))
  panX.value = pointX - rect.left - localX * nextScale
  panY.value = pointY - rect.top - localY * nextScale
  scale.value = nextScale
}

function onWheel(event: WheelEvent) {
  zoomAt(event.deltaY < 0 ? 1.12 : 1 / 1.12, event)
}

function startPan(event: PointerEvent) {
  if ((event.target as HTMLElement).closest('button, input, textarea, select')) return
  panDrag.value = { x: event.clientX, y: event.clientY, panX: panX.value, panY: panY.value }
  ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
}

function movePointer(event: PointerEvent) {
  if (markerDrag.value && currentMap.value) {
    const marker = currentMap.value.markers.find((item) => item.id === markerDrag.value?.id)
    if (marker) {
      const point = localPoint(event.clientX, event.clientY)
      marker.x = point.x
      marker.y = point.y
      markerDrag.value.moved = true
    }
    return
  }
  if (!panDrag.value) return
  panX.value = panDrag.value.panX + event.clientX - panDrag.value.x
  panY.value = panDrag.value.panY + event.clientY - panDrag.value.y
}

async function stopPointer() {
  if (markerDrag.value && currentMap.value) {
    const marker = currentMap.value.markers.find((item) => item.id === markerDrag.value?.id)
    if (marker && markerDrag.value.moved) {
      await map.updateMarker(currentMap.value.id, marker.id, { stationId: marker.station.id, x: marker.x, y: marker.y, size: marker.size })
    }
  }
  markerDrag.value = null
  panDrag.value = null
}

function localPoint(clientX: number, clientY: number) {
  const rect = viewport.value?.getBoundingClientRect()
  if (!rect) return { x: 0, y: 0 }
  return {
    x: Math.round((clientX - rect.left - panX.value) / scale.value * 100) / 100,
    y: Math.round((clientY - rect.top - panY.value) / scale.value * 100) / 100
  }
}

function showHover(marker: MapMarker, event: PointerEvent) {
  hoverMarker.value = marker
  moveHover(event)
}

function moveHover(event: PointerEvent) {
  hoverX.value = Math.min(window.innerWidth - 260, event.clientX + 14)
  hoverY.value = Math.min(window.innerHeight - 170, event.clientY + 14)
}
</script>
