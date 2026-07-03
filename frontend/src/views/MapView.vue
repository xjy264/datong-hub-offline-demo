<template>
  <section class="page map-page" v-loading="map.loading">
    <div class="page-head">
      <div class="head-main">
        <div>
          <div class="eyebrow">整图总览</div>
          <h2 class="page-title">PDF 底图热点入口</h2>
          <p class="subline">点击红色车站或蓝色已撤站图标，进入对应车间页面。</p>
        </div>
        <div class="inline-meta">
          <span class="badge">{{ map.stations.length }} 个点位</span>
          <span class="badge">{{ totalImages }} 张图片</span>
        </div>
      </div>
      <div class="workshop-strip">
        <button v-for="workshop in WORKSHOPS" :key="workshop.id" class="workshop-card" :style="{ '--workshop-color': workshop.color }" @click="router.push(`/workshops/${workshop.id}`)">
          <strong>{{ workshop.name }}</strong>
          <span>{{ workshopStats(workshop.id).total }} 点 · {{ workshopStats(workshop.id).images }} 图</span>
        </button>
      </div>
    </div>

    <section class="panel map-panel">
      <div class="map-toolbar">
        <div class="tool-row">
          <el-input v-model="query" class="search-field" placeholder="搜索站名、里程、车间" clearable />
          <el-select v-model="workshopFilter" class="select-field" aria-label="车间筛选">
            <el-option label="全部车间" value="all" />
            <el-option v-for="workshop in WORKSHOPS" :key="workshop.id" :label="workshop.name" :value="workshop.id" />
          </el-select>
          <el-radio-group v-model="colorFilter">
            <el-radio-button label="all">全部</el-radio-button>
            <el-radio-button label="red">车站</el-radio-button>
            <el-radio-button label="blue">已撤站</el-radio-button>
          </el-radio-group>
        </div>
        <div class="tool-row">
          <span class="count">{{ filteredStations.length }}/{{ map.stations.length }} 点</span>
          <el-button @click="zoomAt(1 / 1.18)">缩小</el-button>
          <el-button @click="zoomAt(1.18)">放大</el-button>
          <el-button @click="fitToViewport">适应整图</el-button>
        </div>
      </div>
      <div ref="viewport" class="viewport" @wheel.prevent="onWheel" @pointerdown="startDrag" @pointermove="moveDrag" @pointerup="stopDrag" @pointercancel="stopDrag">
        <div class="map-canvas" :style="canvasStyle">
          <img class="base-map" :src="fullMap" alt="大同房建公寓段管辖示意图 PDF 底图" />
          <button
            v-for="station in map.stations"
            :key="station.id"
            class="hotspot"
            :class="{ hidden: !visibleIds.has(station.id) }"
            :style="hotspotStyle(station)"
            :title="station.name"
            @click.stop="openStation(station)"
            @pointerover="showHover(station, $event)"
            @pointermove="moveHover($event)"
            @pointerout="hoverStation = null"
          />
        </div>
      </div>
    </section>

    <div v-if="hoverStation" class="hover-card show" :style="hoverStyle">
      <p class="hover-name">{{ hoverStation.name }}</p>
      <div class="hover-meta">{{ colorLabel(hoverStation.color) }} · {{ workshopName(hoverStation.workshopId) }}</div>
      <div class="hover-meta">里程：{{ hoverStation.mileage || '未匹配' }}</div>
      <div class="hover-meta">图片：{{ countImages(hoverStation.folders) }} 张</div>
      <div v-if="firstImages(hoverStation).length" class="hover-photos">
        <img v-for="image in firstImages(hoverStation)" :key="image.id" :src="image.url" alt="" />
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import fullMap from '../assets/full-map.svg'
import { WORKSHOPS, workshopName } from '../constants/workshops'
import { useMapStore } from '../stores/map'
import type { Station, StationFolder, StationImage } from '../types'

const MAP_SIZE = { width: 1191, height: 842 }
const map = useMapStore()
const router = useRouter()
const viewport = ref<HTMLElement | null>(null)
const query = ref('')
const workshopFilter = ref('all')
const colorFilter = ref('all')
const scale = ref(1)
const panX = ref(0)
const panY = ref(0)
const drag = ref<{ x: number; y: number; panX: number; panY: number } | null>(null)
const hoverStation = ref<Station | null>(null)
const hoverX = ref(0)
const hoverY = ref(0)

onMounted(async () => {
  await map.load()
  await nextTick()
  fitToViewport()
})

const totalImages = computed(() => map.stations.reduce((sum, station) => sum + countImages(station.folders), 0))
const filteredStations = computed(() => {
  const text = query.value.trim().toLowerCase()
  return map.stations.filter((station) => {
    const colorOk = colorFilter.value === 'all' || station.color === colorFilter.value
    const workshopOk = workshopFilter.value === 'all' || station.workshopId === workshopFilter.value
    const haystack = `${station.name} ${station.autoName} ${station.mileage} ${workshopName(station.workshopId)}`.toLowerCase()
    return colorOk && workshopOk && (!text || haystack.includes(text))
  })
})
const visibleIds = computed(() => new Set(filteredStations.value.map((station) => station.id)))
const canvasStyle = computed(() => ({ transform: `translate(${panX.value}px, ${panY.value}px) scale(${scale.value})` }))
const hoverStyle = computed(() => ({ left: `${hoverX.value}px`, top: `${hoverY.value}px` }))

function workshopStats(id: string) {
  const stations = map.stations.filter((station) => station.workshopId === id)
  return { total: stations.length, images: stations.reduce((sum, station) => sum + countImages(station.folders), 0) }
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

function hotspotStyle(station: Station) {
  return { '--x': `${station.position.x}px`, '--y': `${station.position.y}px`, '--size': `${station.size || 4.4}px` }
}

function openStation(station: Station) {
  router.push({ path: `/workshops/${station.workshopId}`, query: { focus: station.id } })
}

function fitToViewport() {
  const rect = viewport.value?.getBoundingClientRect()
  if (!rect) return
  scale.value = Math.min((rect.width - 40) / MAP_SIZE.width, (rect.height - 40) / MAP_SIZE.height)
  scale.value = Math.min(2.8, Math.max(0.25, scale.value))
  panX.value = (rect.width - MAP_SIZE.width * scale.value) / 2
  panY.value = (rect.height - MAP_SIZE.height * scale.value) / 2
}

function zoomAt(multiplier: number, event?: WheelEvent) {
  const rect = viewport.value?.getBoundingClientRect()
  if (!rect) return
  const pointX = event ? event.clientX : rect.left + rect.width / 2
  const pointY = event ? event.clientY : rect.top + rect.height / 2
  const localX = (pointX - rect.left - panX.value) / scale.value
  const localY = (pointY - rect.top - panY.value) / scale.value
  const nextScale = Math.min(8, Math.max(0.25, scale.value * multiplier))
  panX.value = pointX - rect.left - localX * nextScale
  panY.value = pointY - rect.top - localY * nextScale
  scale.value = nextScale
}

function onWheel(event: WheelEvent) {
  zoomAt(event.deltaY < 0 ? 1.12 : 1 / 1.12, event)
}

function startDrag(event: PointerEvent) {
  if ((event.target as HTMLElement).closest('button, input, textarea, select')) return
  drag.value = { x: event.clientX, y: event.clientY, panX: panX.value, panY: panY.value }
  ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
}

function moveDrag(event: PointerEvent) {
  if (!drag.value) return
  panX.value = drag.value.panX + event.clientX - drag.value.x
  panY.value = drag.value.panY + event.clientY - drag.value.y
}

function stopDrag() {
  drag.value = null
}

function showHover(station: Station, event: PointerEvent) {
  hoverStation.value = station
  moveHover(event)
}

function moveHover(event: PointerEvent) {
  hoverX.value = Math.min(window.innerWidth - 260, event.clientX + 14)
  hoverY.value = Math.min(window.innerHeight - 170, event.clientY + 14)
}
</script>
