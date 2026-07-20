<template>
  <section class="page map-page" v-loading="map.loading">
    <div class="page-head">
      <div class="head-main">
        <div>
          <div class="eyebrow-row">
            <el-button text class="back-map-button" @click="router.push('/maps')">返回地图选择</el-button>
            <span class="eyebrow">整图总览</span>
          </div>
          <h2 class="page-title">{{ currentMap?.name || '地图' }}</h2>
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
        <div class="workshop-card workshop-action-card">
          <strong>车间管理</strong>
          <div class="workshop-action-controls">
            <el-button type="primary" size="small" @click="createWorkshop">新增车间</el-button>
            <el-button type="danger" plain size="small" @click="openDeleteWorkshopDialog">删除车间</el-button>
          </div>
        </div>
      </div>
    </div>

    <section class="panel map-panel">
      <div class="map-toolbar">
        <div class="tool-row">
          <el-autocomplete
            v-model="query"
            class="search-field"
            placeholder="搜索站名、公里标、车间"
            clearable
            :fetch-suggestions="fetchMarkerSuggestions"
            :trigger-on-focus="false"
            @select="selectSearchSuggestion"
          >
            <template #default="{ item }">
              <div class="search-option-name">{{ item.value }}</div>
              <span class="search-option-detail">{{ item.detail }}</span>
            </template>
          </el-autocomplete>
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
          <el-button @click="openOriginalPdf">查看原始 PDF</el-button>
          <el-button :type="editMode ? 'primary' : 'default'" @click="toggleEdit">{{ editMode ? '完成编辑' : '编辑布局' }}</el-button>
        </div>
      </div>

      <div class="map-editor-layout" :class="{ editing: editMode }">
        <div
          ref="viewport"
          class="viewport"
          @wheel.prevent="onWheel"
          @dragover.prevent
          @drop.prevent="dropMapComponent"
          @pointerdown="startPan"
          @pointermove="movePointer"
          @pointerup="stopPointer"
          @pointercancel="stopPointer"
        >
          <div v-if="currentMap" class="map-canvas" :style="canvasStyle">
            <img class="base-map" :src="currentMap.backgroundUrl" :style="baseMapStyle" alt="地图背景" />
            <button
              v-for="interval in currentMap.intervals"
              :key="interval.id"
              type="button"
              class="interval-hotspot"
              :class="{ selected: selectedIntervalId === interval.id, active: !editMode && selectedSidebarIntervalId === interval.id }"
              :style="intervalStyle(interval)"
              :title="intervalTitle(interval)"
              @click.stop="clickInterval(interval)"
              @pointerdown.stop="startIntervalDrag(interval, $event)"
              @pointerover="showIntervalHover(interval, $event)"
              @pointermove="moveHover($event)"
              @pointerout="hoverInterval = null"
            />
            <button
              v-if="intervalDraft"
              type="button"
              class="interval-hotspot selected draft-interval"
              :style="intervalDraftStyle"
              title="新车站区间"
              @pointerdown.stop="startDraftIntervalDrag($event)"
            />
            <button
              v-for="marker in currentMap.markers"
              :key="marker.id"
              class="hotspot marker-hotspot"
              :class="{ hidden: !visibleMarkerIds.has(marker.id), selected: selectedMarkerId === marker.id, active: !editMode && selectedSidebarStationId === marker.station.id, 'interval-endpoint': intervalEndpointMarkerIds.has(marker.id) }"
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
              :style="markerStyle({ ...draftMarker, color: selectedMarkerType })"
              title="新按钮"
            />
          </div>
        </div>

        <aside class="station-sidebar">
          <div v-if="editMode" class="station-action-panel">
            <div class="eyebrow">地图组件</div>
            <button type="button" class="new-marker-drag station-action-card" draggable="true" @dragstart="startNewMarkerDrag">
              <span class="new-marker-preview">
                <span class="new-marker-dot red"></span>
                <span class="new-marker-dot blue"></span>
              </span>
              <strong>新增车站按钮</strong>
              <small>拖到 PDF 上</small>
            </button>
            <button type="button" class="new-marker-drag station-action-card" draggable="true" @dragstart="startNewIntervalDrag">
              <span class="new-interval-preview"></span>
              <strong>新增车站区间</strong>
              <small>拖到 PDF 上</small>
            </button>
            <p class="palette-hint">将车站按钮或车站区间拖到 PDF 上，再在下方填写对应信息。</p>
          </div>

          <div v-if="editMode && (intervalDraft || selectedInterval)" class="marker-form">
            <h3 class="panel-title">{{ intervalDraft ? '新增车站区间' : '编辑车站区间' }}</h3>
            <el-form label-position="top" class="marker-edit-fields">
              <el-form-item label="车站 A">
                <el-select v-model="intervalForm.markerAId" filterable clearable placeholder="可选车站按钮" style="width: 100%">
                  <el-option v-for="marker in currentMap?.markers || []" :key="marker.id" :label="markerOptionLabel(marker)" :value="marker.id" />
                </el-select>
              </el-form-item>
              <el-form-item label="车站 B">
                <el-select v-model="intervalForm.markerBId" filterable clearable placeholder="可选车站按钮" style="width: 100%">
                  <el-option v-for="marker in currentMap?.markers || []" :key="marker.id" :label="markerOptionLabel(marker)" :value="marker.id" />
                </el-select>
              </el-form-item>
              <el-form-item label="区间长度">
                <div class="interval-direction-fields">
                  <el-input-number v-model="intervalForm.length" :min="2" :max="300" :step="1" controls-position="right" style="width: 100%" />
                  <el-slider v-model="intervalForm.length" :min="2" :max="300" :step="1" />
                  <small>调整时地图上会实时预览。</small>
                </div>
              </el-form-item>
              <el-form-item label="方向角度（绝对方向）">
                <div class="interval-direction-fields">
                  <el-input-number v-model="intervalForm.angle" :min="-180" :max="180" :step="1" controls-position="right" style="width: 100%" />
                  <el-slider v-model="intervalForm.angle" :min="-180" :max="180" :step="1" />
                  <small>0° 为水平向右，90° 为竖直。</small>
                </div>
              </el-form-item>
              <el-form-item label="基站信息列表">
                <div class="base-station-fields">
                  <div v-for="(_, index) in intervalForm.baseStations" :key="index" class="base-station-field">
                    <el-input v-model="intervalForm.baseStations[index]" :placeholder="`第 ${index + 1} 条基站信息`" maxlength="200" />
                    <el-button type="danger" plain aria-label="删除基站信息" @click="removeBaseStation(index)">删除</el-button>
                  </div>
                  <el-button plain @click="addBaseStation">新增一条</el-button>
                </div>
              </el-form-item>
            </el-form>
            <div class="button-row">
              <el-button type="primary" @click="saveInterval">保存区间</el-button>
              <el-button v-if="selectedInterval" type="danger" plain @click="deleteInterval">删除区间</el-button>
              <el-button @click="clearIntervalEdit">取消</el-button>
            </div>
          </div>

          <div v-if="editMode && (selectedMarker || draftMarker)" class="marker-form">
            <h3 class="panel-title">{{ draftMarker ? '新增按钮配置' : '选中按钮配置' }}</h3>
            <template v-if="draftMarker">
              <el-form label-position="top" class="marker-edit-fields">
                <el-form-item label="车站名称">
                  <el-input v-model="draftStationName" placeholder="请输入车站名称" maxlength="128" />
                </el-form-item>
                <el-form-item label="状态">
                  <el-radio-group v-model="selectedMarkerType" class="marker-type-group" :disabled="!!draftExistingStation">
                    <el-radio-button label="red">车站</el-radio-button>
                    <el-radio-button label="blue">已撤站</el-radio-button>
                  </el-radio-group>
                </el-form-item>
                <p v-if="draftExistingStation" class="matched-station-hint">已匹配已有车站，将使用原车间：{{ workshopName(draftExistingStation.workshopId) }}</p>
                <el-form-item label="所属车间">
                  <el-select
                    :model-value="draftExistingStation?.workshopId ?? draftStationWorkshopId"
                    placeholder="请选择所属车间"
                    style="width: 100%"
                    :disabled="!!draftExistingStation"
                    @update:model-value="draftStationWorkshopId = $event"
                  >
                    <el-option v-for="workshop in workshops" :key="workshop.id" :label="workshop.name" :value="workshop.id" />
                  </el-select>
                </el-form-item>
              </el-form>
              <div class="button-row" style="margin-top: 8px">
                <el-button type="primary" :disabled="!canSaveDraftMarker" @click="saveSelectedMarker">保存新增按钮</el-button>
                <el-button type="danger" plain @click="deleteSelectedMarker()">取消</el-button>
              </div>
            </template>
            <template v-else>
              <el-form label-position="top" class="marker-edit-fields">
                <el-form-item label="这个站为">
                  <el-select v-model="selectedMarkerStationId" filterable placeholder="请选择车站" style="width: 100%">
                    <el-option v-for="station in markerTypeStations" :key="station.id" :label="station.name" :value="station.id" />
                  </el-select>
                </el-form-item>
              </el-form>
              <div class="button-row" style="margin-top: 8px">
                <el-button type="primary" :disabled="!selectedMarkerStationId" @click="saveSelectedMarker">保存按钮</el-button>
                <el-button type="danger" plain @click="deleteSelectedMarker(true)">删除地图按钮</el-button>
              </div>
            </template>
          </div>
          <template v-if="selectedSidebarInterval">
            <div class="eyebrow">当前车站区间</div>
            <dl class="sidebar-info interval-sidebar-info">
              <div>
                <dt>车站 A</dt>
                <dd>{{ intervalStationName(selectedSidebarInterval.markerAId) }}</dd>
              </div>
              <div>
                <dt>车站 B</dt>
                <dd>{{ intervalStationName(selectedSidebarInterval.markerBId) }}</dd>
              </div>
              <div>
                <dt>基站信息列表</dt>
                <dd>
                  <ol class="base-station-list">
                    <li v-for="(item, index) in selectedSidebarInterval.baseStations" :key="index">{{ item }}</li>
                  </ol>
                </dd>
              </div>
            </dl>
          </template>
          <template v-else-if="selectedSidebarStation">
            <div class="eyebrow">当前车站</div>
            <el-form label-position="top" class="sidebar-form">
              <el-form-item label="站点名称">
                <el-input v-model="sidebarForm.name" :disabled="savingSidebarStation" @change="saveSidebarStation" />
              </el-form-item>
              <el-form-item label="公里标">
                <el-input v-model="sidebarForm.mileage" maxlength="64" :disabled="savingSidebarStation" @change="saveSidebarStation" />
              </el-form-item>
              <el-form-item label="状态">
                <el-radio-group v-model="sidebarForm.color" :disabled="savingSidebarStation" @change="saveSidebarStation">
                  <el-radio-button label="red">车站</el-radio-button>
                  <el-radio-button label="blue">已撤站</el-radio-button>
                </el-radio-group>
              </el-form-item>
              <el-form-item label="所属车间">
                <el-select v-model="sidebarForm.workshopId" :disabled="savingSidebarStation" style="width: 100%" @change="saveSidebarStation">
                  <el-option v-for="workshop in workshops" :key="workshop.id" :label="workshop.name" :value="workshop.id" />
                </el-select>
              </el-form-item>
            </el-form>
            <dl class="sidebar-info">
              <div>
                <dt>图片数量</dt>
                <dd>{{ countImages(selectedSidebarStation.folders) }} 张</dd>
              </div>
              <div>
                <dt>备注</dt>
                <dd>{{ selectedSidebarStation.notes || '暂无备注' }}</dd>
              </div>
            </dl>
            <el-button type="primary" style="width: 100%" @click="router.push(stationDetailPath(selectedSidebarStation))">进入详情页面</el-button>
          </template>
          <div v-else class="empty">点击地图上的车站或区间查看信息</div>
        </aside>
      </div>
    </section>

    <div v-if="hoverMarker" class="hover-card show" :style="hoverStyle">
      <p class="hover-name">{{ hoverMarker.station.name }}</p>
      <div class="hover-meta">{{ colorLabel(hoverMarker.station.color) }} · {{ workshopName(hoverMarker.station.workshopId) }}</div>
      <div class="hover-meta">公里标：{{ hoverMarker.station.mileage || '未匹配' }}</div>
      <div class="hover-meta">图片：{{ countImages(hoverMarker.station.folders) }} 张</div>
      <div v-if="firstImages(hoverMarker.station).length" class="hover-photos">
        <img v-for="image in firstImages(hoverMarker.station)" :key="image.id" :src="image.url" alt="" />
      </div>
    </div>

    <div v-if="hoverInterval" class="hover-card show interval-hover-card" :style="hoverStyle">
      <ol class="base-station-list hover-base-station-list">
        <li v-for="(item, index) in hoverInterval.baseStations" :key="index">{{ item }}</li>
      </ol>
    </div>

    <el-dialog v-model="deleteWorkshopDialogVisible" title="删除车间" width="420px">
      <el-form label-position="top">
        <el-form-item label="选择要删除的车间">
          <el-select v-model="deleteWorkshopId" placeholder="请选择车间" style="width: 100%">
            <el-option v-for="workshop in workshops" :key="workshop.id" :label="workshop.name" :value="workshop.id" />
          </el-select>
        </el-form-item>
      </el-form>
      <p class="palette-hint">删除后，已绑定车站将变为未分组车间。</p>
      <template #footer>
        <el-button @click="deleteWorkshopDialogVisible = false">取消</el-button>
        <el-button type="danger" :disabled="deleteWorkshopId == null" @click="deleteWorkshop">确认删除</el-button>
      </template>
    </el-dialog>
  </section>
</template>

<script setup lang="ts">
import { ElMessage, ElMessageBox } from 'element-plus'
import { computed, nextTick, onMounted, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useMapStore } from '../stores/map'
import type { MapInterval, MapMarker, Station, StationFolder, StationImage } from '../types'
import { isHandledApiError, normalizeRequiredName, positionSnapshot, restorePosition } from '../utils/actionFeedback'
import { createIntervalDraft } from '../utils/intervalDraft'
import { intervalGeometry, intervalPreviewGeometry } from '../utils/intervalGeometry'
import { nextSidebarStationId, sidebarSelectionOnEditToggle } from '../utils/mapMarkerClick'
import { focusMarkerTransform, markerSuggestions } from '../utils/mapSearch'
import { createMarkerDraft } from '../utils/markerDraft'
import { intervalMarkerLabel, markerEditStationOptions, markerTypeForStation } from '../utils/markerEdit'
import { DEFAULT_MARKER_SIZE, markerCssVars } from '../utils/markerStyle'
import { findStationByName } from '../utils/stationMatch'
import { stationDetailPath } from '../utils/stationRoute'
import { workshopName as resolveWorkshopName, workshopPath } from '../utils/workshopRoute'

type DraftMarker = { x: number; y: number; size: number }
type IntervalForm = { markerAId: string | null; markerBId: string | null; baseStations: string[]; x: number; y: number; length: number; angle: number }
type SearchSuggestion = ReturnType<typeof markerSuggestions>[number]
type Position = ReturnType<typeof positionSnapshot>

const map = useMapStore()
const router = useRouter()
const route = useRoute()
const viewport = ref<HTMLElement | null>(null)
const query = ref('')
const workshopFilter = ref<number | 'all'>('all')
const colorFilter = ref('all')
const editMode = ref(false)
const selectedMarkerId = ref('')
const selectedMarkerStationId = ref('')
const selectedMarkerType = ref<'red' | 'blue'>('red')
const selectedIntervalId = ref('')
const selectedSidebarIntervalId = ref('')
const intervalDraft = ref(false)
const intervalForm = reactive<IntervalForm>({ markerAId: null, markerBId: null, baseStations: [''], x: 0, y: 0, length: 12, angle: 0 })
const draftStationName = ref('')
const draftStationWorkshopId = ref<number | null>(null)
const deleteWorkshopDialogVisible = ref(false)
const deleteWorkshopId = ref<number | null>(null)
const selectedSidebarStationId = ref('')
const savingSidebarStation = ref(false)
const sidebarForm = reactive<{ name: string; mileage: string; workshopId: number | null; color: 'red' | 'blue' }>({ name: '', mileage: '', workshopId: null, color: 'red' })
const scale = ref(1)
const panX = ref(0)
const panY = ref(0)
const panDrag = ref<{ x: number; y: number; panX: number; panY: number } | null>(null)
const markerDrag = ref<{ id: string; moved: boolean; original: Position } | null>(null)
const intervalDrag = ref<{ id: string | null; moved: boolean; original: Position } | null>(null)
const draftMarker = ref<DraftMarker | null>(null)
const hoverMarker = ref<MapMarker | null>(null)
const hoverInterval = ref<MapInterval | null>(null)
const hoverX = ref(0)
const hoverY = ref(0)

onMounted(async () => {
  await map.load()
  const routeMapId = typeof route.query.mapId === 'string' ? route.query.mapId : ''
  if (routeMapId && routeMapId !== map.currentMap?.id) await map.loadMap(routeMapId)
  ensureSidebarSelection()
  await nextTick()
  fitToViewport()
})

watch(() => map.currentMap?.id, async (id) => {
  selectedMarkerId.value = ''
  selectedSidebarStationId.value = ''
  selectedSidebarIntervalId.value = ''
  clearIntervalEdit()
  clearDraftMarker()
  ensureSidebarSelection()
  await nextTick()
  fitToViewport()
})

watch(() => map.currentMap?.markers.map((marker) => `${marker.id}:${marker.station.id}`).join('|') || '', () => ensureSidebarSelection())

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
const intervalEndpointMarkerIds = computed(() => new Set((currentMap.value?.intervals || [])
  .flatMap((interval) => [interval.markerAId, interval.markerBId])
  .filter((markerId): markerId is string => Boolean(markerId))))
const canvasStyle = computed(() => ({ transform: `translate(${panX.value}px, ${panY.value}px) scale(${scale.value})`, width: `${currentMap.value?.width || 1191}px`, height: `${currentMap.value?.height || 842}px` }))
const baseMapStyle = computed(() => ({ width: `${currentMap.value?.width || 1191}px`, height: `${currentMap.value?.height || 842}px` }))
const hoverStyle = computed(() => ({ left: `${hoverX.value}px`, top: `${hoverY.value}px` }))
const selectedMarker = computed(() => currentMap.value?.markers.find((marker) => marker.id === selectedMarkerId.value) || null)
const selectedInterval = computed(() => currentMap.value?.intervals.find((interval) => interval.id === selectedIntervalId.value) || null)
const selectedSidebarInterval = computed(() => currentMap.value?.intervals.find((interval) => interval.id === selectedSidebarIntervalId.value) || null)
const selectedSidebarStation = computed(() => map.stations.find((station) => station.id === selectedSidebarStationId.value) || null)
const selectedMarkerStation = computed(() => map.stations.find((station) => station.id === selectedMarkerStationId.value) || null)
const markerTypeStations = computed(() => markerEditStationOptions(map.stations))
const draftExistingStation = computed(() => findStationByName(map.stations, draftStationName.value))
const canSaveDraftMarker = computed(() => !!draftStationName.value.trim() && (!!draftExistingStation.value || draftStationWorkshopId.value != null))
const intervalDraftStyle = computed(() => intervalGeometryStyle(intervalGeometry(intervalForm)))

watch(selectedSidebarStation, syncSidebarForm)

watch(selectedMarkerStationId, (stationId) => {
  if (!draftMarker.value) {
    selectedMarkerType.value = markerTypeForStation(map.stations, stationId, selectedMarkerType.value)
    if (stationId) selectedSidebarStationId.value = stationId
  }
})

watch(draftExistingStation, (station) => {
  if (station) selectedMarkerType.value = stationType(station)
})

function workshopName(id: number | string | null | undefined) {
  return resolveWorkshopName(workshops.value, id)
}

function fetchMarkerSuggestions(text: string, cb: (items: SearchSuggestion[]) => void) {
  cb(markerSuggestions(currentMap.value?.markers || [], text, workshopName))
}

function selectSearchSuggestion(item: SearchSuggestion) {
  const marker = currentMap.value?.markers.find((candidate) => candidate.id === item.markerId)
  const rect = viewport.value?.getBoundingClientRect()
  if (!marker || !rect) return
  workshopFilter.value = 'all'
  colorFilter.value = 'all'
  selectedMarkerId.value = marker.id
  selectedSidebarIntervalId.value = ''
  selectedSidebarStationId.value = marker.station.id
  const transform = focusMarkerTransform(marker, currentMap.value?.markers || [], { width: rect.width, height: rect.height })
  scale.value = transform.scale
  panX.value = transform.panX
  panY.value = transform.panY
}

function workshopStats(id: number) {
  const stations = map.stations.filter((station) => station.workshopId === id)
  const stationIds = new Set(stations.map((station) => station.id))
  const markers = currentMap.value?.markers.filter((marker) => stationIds.has(marker.station.id)).length || 0
  return { total: stations.length, markers }
}

function syncSidebarForm() {
  if (!selectedSidebarStation.value) return
  sidebarForm.name = selectedSidebarStation.value.name
  sidebarForm.mileage = selectedSidebarStation.value.mileage || ''
  sidebarForm.workshopId = selectedSidebarStation.value.workshopId
  sidebarForm.color = stationType(selectedSidebarStation.value)
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

function stationType(station: Pick<Station, 'color'> | null | undefined): 'red' | 'blue' {
  return station?.color === 'blue' ? 'blue' : 'red'
}

function stationMarkerSize(station: Pick<Station, 'size'> | null | undefined) {
  return station?.size || DEFAULT_MARKER_SIZE
}

function markerStyle(marker: { x: number; y: number; size?: number; color?: string; station?: Station }) {
  return markerCssVars({
    x: marker.x,
    y: marker.y,
    size: marker.station ? stationMarkerSize(marker.station) : marker.size || DEFAULT_MARKER_SIZE,
    color: marker.station ? marker.station.color : marker.color
  })
}

function intervalGeometryStyle(geometry: ReturnType<typeof intervalGeometry>) {
  return {
    '--interval-x': `${geometry.x}px`,
    '--interval-y': `${geometry.y}px`,
    '--interval-width': `${geometry.width}px`,
    '--interval-angle': `${geometry.angle}deg`
  }
}

function intervalStyle(interval: MapInterval) {
  return intervalGeometryStyle(intervalPreviewGeometry(interval, selectedIntervalId.value, intervalForm))
}

function intervalTitle(interval: MapInterval) {
  return `${intervalStationName(interval.markerAId)}—${intervalStationName(interval.markerBId)}车站区间`
}

function markerOptionLabel(marker: MapMarker) {
  return intervalMarkerLabel(marker)
}

function intervalStationName(markerId: string | null) {
  if (!markerId) return '未选择'
  return currentMap.value?.markers.find((marker) => marker.id === markerId)?.station.name || '车站按钮不存在'
}

function ensureSidebarSelection() {
  const markerStationIds = new Set((currentMap.value?.markers || []).map((marker) => marker.station.id))
  if (selectedSidebarStationId.value && markerStationIds.has(selectedSidebarStationId.value)) return
  selectedSidebarStationId.value = currentMap.value?.markers[0]?.station.id || ''
}

async function createWorkshop() {
  let inputValue: string
  try {
    inputValue = (await ElMessageBox.prompt('请输入车间名称', '新增车间', { inputValue: '新车间' })).value
  } catch {
    return
  }
  const name = normalizeRequiredName(inputValue)
  if (!name) {
    ElMessage.warning('车间名称不能为空')
    return
  }
  const workshop = await map.createWorkshop(name)
  ElMessage.success('已新增车间')
  router.push(workshopPath(workshop))
}

function openDeleteWorkshopDialog() {
  deleteWorkshopId.value = null
  deleteWorkshopDialogVisible.value = true
}

async function deleteWorkshop() {
  const workshop = workshops.value.find((item) => item.id === deleteWorkshopId.value)
  if (!workshop) {
    ElMessage.warning('请选择要删除的车间')
    return
  }
  await map.deleteWorkshop(workshop.id)
  if (workshopFilter.value === workshop.id) workshopFilter.value = 'all'
  if (draftStationWorkshopId.value === workshop.id) draftStationWorkshopId.value = null
  deleteWorkshopId.value = null
  deleteWorkshopDialogVisible.value = false
  ElMessage.success('已删除车间')
}

async function saveSidebarStation() {
  if (!selectedSidebarStation.value) return
  const name = sidebarForm.name.trim()
  if (!name) {
    ElMessage.warning('站点名称不能为空')
    syncSidebarForm()
    return
  }
  savingSidebarStation.value = true
  try {
    await map.updateProfile(selectedSidebarStation.value.id, { name, notes: selectedSidebarStation.value.notes || '', mileage: sidebarForm.mileage, workshopId: sidebarForm.workshopId, color: sidebarForm.color })
    ElMessage.success('已保存')
  } finally {
    savingSidebarStation.value = false
  }
}

function toggleEdit() {
  editMode.value = !editMode.value
  selectedMarkerId.value = ''
  selectedSidebarStationId.value = sidebarSelectionOnEditToggle(editMode.value, selectedSidebarStationId.value)
  selectedSidebarIntervalId.value = sidebarSelectionOnEditToggle(editMode.value, selectedSidebarIntervalId.value)
  intervalDrag.value = null
  clearDraftMarker()
  clearIntervalEdit()
}

function beginNewInterval(point: { x: number; y: number }) {
  clearDraftMarker()
  selectedMarkerId.value = ''
  selectedMarkerStationId.value = ''
  selectedIntervalId.value = ''
  selectedSidebarIntervalId.value = ''
  selectedSidebarStationId.value = ''
  intervalDraft.value = true
  intervalForm.markerAId = null
  intervalForm.markerBId = null
  intervalForm.baseStations = ['']
  Object.assign(intervalForm, createIntervalDraft(point))
}

function clickInterval(interval: MapInterval) {
  selectedSidebarIntervalId.value = interval.id
  selectedSidebarStationId.value = ''
  if (!editMode.value) return
  clearDraftMarker()
  selectedMarkerId.value = ''
  intervalDraft.value = false
  selectedIntervalId.value = interval.id
  intervalForm.markerAId = interval.markerAId
  intervalForm.markerBId = interval.markerBId
  intervalForm.baseStations = [...interval.baseStations]
  intervalForm.x = interval.x
  intervalForm.y = interval.y
  intervalForm.length = interval.length
  intervalForm.angle = interval.angle
}

function addBaseStation() {
  intervalForm.baseStations.push('')
}

function removeBaseStation(index: number) {
  intervalForm.baseStations.splice(index, 1)
  if (!intervalForm.baseStations.length) intervalForm.baseStations.push('')
}

async function saveInterval() {
  if (!currentMap.value) return
  const body = {
    markerAId: intervalForm.markerAId,
    markerBId: intervalForm.markerBId,
    baseStations: intervalForm.baseStations.map((item) => item.trim()).filter(Boolean),
    x: intervalForm.x,
    y: intervalForm.y,
    length: intervalForm.length,
    angle: intervalForm.angle
  }
  if (intervalDraft.value) await map.createInterval(currentMap.value.id, body)
  else if (selectedInterval.value) await map.updateInterval(currentMap.value.id, selectedInterval.value.id, body)
  clearIntervalEdit()
  ElMessage.success('已保存车站区间')
}

async function deleteInterval() {
  if (!currentMap.value || !selectedInterval.value) return
  const confirmed = await ElMessageBox.confirm('删除后将无法恢复。', '删除车站区间', {
    confirmButtonText: '确认删除', cancelButtonText: '取消', type: 'warning'
  }).then(() => true).catch(() => false)
  if (!confirmed) return
  await map.deleteInterval(currentMap.value.id, selectedInterval.value.id)
  clearIntervalEdit()
  selectedSidebarIntervalId.value = ''
  ensureSidebarSelection()
  ElMessage.success('已删除车站区间')
}

function clearIntervalEdit() {
  intervalDraft.value = false
  selectedIntervalId.value = ''
  intervalDrag.value = null
  intervalForm.markerAId = null
  intervalForm.markerBId = null
  intervalForm.baseStations = ['']
  intervalForm.x = 0
  intervalForm.y = 0
  intervalForm.length = 12
  intervalForm.angle = 0
}

function startNewMarkerDrag(event: DragEvent) {
  event.dataTransfer?.setData('new-marker', '1')
  if (event.dataTransfer) event.dataTransfer.effectAllowed = 'copy'
}

function startNewIntervalDrag(event: DragEvent) {
  event.dataTransfer?.setData('new-interval', '1')
  if (event.dataTransfer) event.dataTransfer.effectAllowed = 'copy'
}

function dropMapComponent(event: DragEvent) {
  if (!editMode.value || !currentMap.value) return
  const point = localPoint(event.clientX, event.clientY)
  if (event.dataTransfer?.getData('new-interval') === '1') {
    beginNewInterval(point)
    return
  }
  if (event.dataTransfer?.getData('new-marker') !== '1') return
  clearIntervalEdit()
  clearDraftMarker()
  const draft = createMarkerDraft(point)
  draftMarker.value = draft.marker
  draftStationName.value = ''
  draftStationWorkshopId.value = null
  selectedMarkerId.value = ''
  selectedSidebarIntervalId.value = ''
  selectedSidebarStationId.value = ''
  selectedMarkerStationId.value = draft.stationId
  selectedMarkerType.value = 'red'
}

function clickMarker(marker: MapMarker) {
  const sidebarStationId = nextSidebarStationId(editMode.value, selectedSidebarStationId.value, marker.station.id)
  selectedSidebarIntervalId.value = ''
  if (editMode.value) {
    clearDraftMarker()
    clearIntervalEdit()
    selectedMarkerId.value = marker.id
    selectedSidebarStationId.value = marker.station.id
    selectedMarkerStationId.value = marker.station.id
    selectedMarkerType.value = stationType(marker.station)
    return
  }
  selectedSidebarStationId.value = sidebarStationId
}

function startMarkerDrag(marker: MapMarker, event: PointerEvent) {
  if (!editMode.value) return
  clearDraftMarker()
  clearIntervalEdit()
  selectedSidebarIntervalId.value = ''
  selectedMarkerId.value = marker.id
  selectedSidebarStationId.value = marker.station.id
  selectedMarkerStationId.value = marker.station.id
  selectedMarkerType.value = stationType(marker.station)
  markerDrag.value = { id: marker.id, moved: false, original: positionSnapshot(marker) }
  ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
}

function startIntervalDrag(interval: MapInterval, event: PointerEvent) {
  if (!editMode.value) return
  if (selectedIntervalId.value !== interval.id) clickInterval(interval)
  intervalDrag.value = { id: interval.id, moved: false, original: positionSnapshot(interval) }
  ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
}

function startDraftIntervalDrag(event: PointerEvent) {
  if (!editMode.value || !intervalDraft.value) return
  intervalDrag.value = { id: null, moved: false, original: positionSnapshot(intervalForm) }
  ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
}

function intervalPayload(interval: Pick<MapInterval, 'markerAId' | 'markerBId' | 'baseStations' | 'x' | 'y' | 'length' | 'angle'>) {
  return {
    markerAId: interval.markerAId,
    markerBId: interval.markerBId,
    baseStations: interval.baseStations,
    x: interval.x,
    y: interval.y,
    length: interval.length,
    angle: interval.angle
  }
}

async function saveSelectedMarker() {
  if (!currentMap.value) return
  if (draftMarker.value) {
    const name = draftStationName.value.trim()
    if (!name) {
      ElMessage.warning('请输入车站名称')
      return
    }
    const existingStation = draftExistingStation.value
    if (!existingStation && draftStationWorkshopId.value == null) {
      ElMessage.warning('请选择所属车间')
      return
    }
    const mapId = currentMap.value.id
    const draft = draftMarker.value
    const station = existingStation || await map.createStation({ name, color: selectedMarkerType.value, workshopId: draftStationWorkshopId.value!, x: draft.x, y: draft.y, size: draft.size })
    await map.createMarker(mapId, {
      stationId: station.id,
      x: draft.x,
      y: draft.y,
      size: stationMarkerSize(station)
    })
    clearDraftMarker()
    ElMessage.success('已新增车站按钮')
    return
  }
  if (!selectedMarkerStationId.value) {
    ElMessage.warning('请选择按钮对应的车站')
    return
  }
  const station = selectedMarkerStation.value
  const marker = selectedMarker.value
  if (!station || !marker) return
  const stationSize = stationMarkerSize(station)
  await map.updateMarker(currentMap.value.id, marker.id, {
    stationId: selectedMarkerStationId.value,
    x: marker.x,
    y: marker.y,
    size: stationSize
  })
  ElMessage.success('已保存组件')
}

async function deleteSelectedMarker(confirmDelete = false) {
  if (draftMarker.value) {
    clearDraftMarker()
    return
  }
  if (!currentMap.value || !selectedMarker.value) return
  if (confirmDelete) {
    const confirmed = await ElMessageBox.confirm('只删除当前地图按钮，不删除车站资料、目录和图片。', '删除地图按钮', {
      confirmButtonText: '确认删除',
      cancelButtonText: '取消',
      type: 'warning'
    }).then(() => true).catch(() => false)
    if (!confirmed) return
  }
  const mapId = currentMap.value.id
  const markerId = selectedMarker.value.id
  await map.deleteMarker(mapId, markerId)
  selectedMarkerId.value = ''
  selectedMarkerStationId.value = ''
  ensureSidebarSelection()
  ElMessage.success('已删除地图按钮')
}

function clearDraftMarker() {
  draftMarker.value = null
  draftStationName.value = ''
  draftStationWorkshopId.value = null
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
  if (intervalDrag.value && currentMap.value) {
    const point = localPoint(event.clientX, event.clientY)
    if (intervalDrag.value.id == null) {
      intervalForm.x = point.x
      intervalForm.y = point.y
    } else {
      const interval = currentMap.value.intervals.find((item) => item.id === intervalDrag.value?.id)
      if (interval) {
        interval.x = point.x
        interval.y = point.y
        intervalForm.x = point.x
        intervalForm.y = point.y
      }
    }
    intervalDrag.value.moved = true
    return
  }
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
  if (intervalDrag.value && currentMap.value) {
    const drag = intervalDrag.value
    const interval = drag.id == null ? null : currentMap.value.intervals.find((item) => item.id === drag.id)
    if (interval && drag.moved) {
      try {
        await map.updateInterval(currentMap.value.id, interval.id, intervalPayload(intervalForm))
        ElMessage.success('区间位置已自动保存')
      } catch (error) {
        restorePosition(interval, drag.original)
        restorePosition(intervalForm, drag.original)
        if (!isHandledApiError(error)) throw error
      }
    }
    intervalDrag.value = null
    panDrag.value = null
    return
  }
  if (markerDrag.value && currentMap.value) {
    const drag = markerDrag.value
    const marker = currentMap.value.markers.find((item) => item.id === drag.id)
    if (marker && drag.moved) {
      try {
        await map.updateMarker(currentMap.value.id, marker.id, { stationId: marker.station.id, x: marker.x, y: marker.y, size: stationMarkerSize(marker.station) })
        ElMessage.success('车站按钮位置已自动保存')
      } catch (error) {
        restorePosition(marker, drag.original)
        if (!isHandledApiError(error)) throw error
      }
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
  hoverInterval.value = null
  moveHover(event)
}

function showIntervalHover(interval: MapInterval, event: PointerEvent) {
  hoverInterval.value = interval
  hoverMarker.value = null
  moveHover(event)
}

function moveHover(event: PointerEvent) {
  hoverX.value = Math.min(window.innerWidth - 260, event.clientX + 14)
  hoverY.value = Math.min(window.innerHeight - 170, event.clientY + 14)
}
</script>
