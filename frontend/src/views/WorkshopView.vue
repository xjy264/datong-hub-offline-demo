<template>
  <section class="page workshop-page" v-loading="map.loading">
    <div class="page-head">
      <div class="crumbs">
        <el-button text @click="router.push('/map')">地图</el-button>
        <button v-if="workshop" class="crumb current crumb-edit" title="点击修改车间名称" @click="startRenameWorkshop">{{ workshop.name }}</button>
        <span v-else class="crumb current">车间</span>
      </div>
      <div class="head-main">
        <div>
          <div class="eyebrow">车间页面</div>
          <h2 v-if="!editingName" class="page-title">
            <button class="title-edit" title="点击修改车间名称" @click="startRenameWorkshop">{{ workshop?.name || '车间' }}</button>
          </h2>
          <div v-else class="workshop-name-editor">
            <el-input v-model="workshopNameDraft" autofocus maxlength="128" @keyup.enter="saveWorkshopName" @keyup.esc="cancelRenameWorkshop" />
            <el-button type="primary" :loading="savingWorkshopName" @click="saveWorkshopName">保存</el-button>
            <el-button @click="cancelRenameWorkshop">取消</el-button>
          </div>
          <p class="subline">站点从整张 PDF 热点进入，在这里集中查看并打开专用详情页。</p>
        </div>
      </div>
    </div>
    <div class="summary-grid">
      <div class="metric"><b>{{ stationList.length }}</b><span>全部点位</span></div>
      <div class="metric"><b>{{ stationList.filter((item) => item.color === 'red').length }}</b><span>车站</span></div>
      <div class="metric"><b>{{ stationList.filter((item) => item.color === 'blue').length }}</b><span>已撤站</span></div>
      <div class="metric"><b>{{ stationList.reduce((sum, item) => sum + countImages(item.folders), 0) }}</b><span>图片</span></div>
    </div>
    <section class="panel">
      <div class="workshop-toolbar">
        <div class="tool-row">
          <el-input v-model="query" class="search-field" placeholder="搜索本车间站点、里程" clearable />
          <el-radio-group v-model="colorFilter">
            <el-radio-button label="all">全部</el-radio-button>
            <el-radio-button label="red">车站</el-radio-button>
            <el-radio-button label="blue">已撤站</el-radio-button>
          </el-radio-group>
        </div>
        <span class="count">{{ filteredStations.length }}/{{ stationList.length }} 点</span>
      </div>
      <div class="station-list">
        <button v-for="station in filteredStations" :key="station.id" class="station-row" :class="{ focused: station.id === focusId }" @click="router.push(stationDetailPath(station))">
          <span>
            <strong><span class="color-dot" :style="{ '--dot': station.color === 'blue' ? '#0000ff' : '#ff0000' }"></span>{{ station.name }}</strong>
            <span class="meta">{{ station.color === 'blue' ? '已撤站' : '车站' }} · 里程 {{ station.mileage || '未匹配' }} · 图片 {{ countImages(station.folders) }} 张</span>
          </span>
          <span class="badge">详情</span>
        </button>
        <div v-if="!filteredStations.length" class="empty">没有匹配的站点</div>
      </div>
    </section>
  </section>
</template>

<script setup lang="ts">
import { ElMessage } from 'element-plus'
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useMapStore } from '../stores/map'
import type { StationFolder } from '../types'
import { stationDetailPath } from '../utils/stationRoute'
import { resolveWorkshopRoute } from '../utils/workshopRoute'

const route = useRoute()
const router = useRouter()
const map = useMapStore()
const query = ref('')
const colorFilter = ref('all')
const editingName = ref(false)
const savingWorkshopName = ref(false)
const workshopNameDraft = ref('')
const focusId = computed(() => String(route.query.focus || ''))
const resolved = computed(() => resolveWorkshopRoute(map.workshops, String(route.params.id || '')))
const workshop = computed(() => resolved.value.workshop)
const stationList = computed(() => {
  const id = workshop.value?.id
  return map.stations.filter((station) => id != null && station.workshopId === id).sort((a, b) => a.position.y - b.position.y || a.position.x - b.position.x)
})
const filteredStations = computed(() => {
  const text = query.value.trim().toLowerCase()
  return stationList.value.filter((station) => {
    const colorOk = colorFilter.value === 'all' || station.color === colorFilter.value
    const haystack = `${station.name} ${station.autoName} ${station.mileage}`.toLowerCase()
    return colorOk && (!text || haystack.includes(text))
  })
})

onMounted(async () => {
  await map.load()
  redirectLegacyWorkshop()
})

watch(() => [route.params.id, map.workshops.length], redirectLegacyWorkshop)

function countImages(folders: StationFolder[]): number {
  return folders.reduce((sum, folder) => sum + folder.images.length + countImages(folder.children), 0)
}

function redirectLegacyWorkshop() {
  if (resolved.value.replacePath) router.replace({ path: resolved.value.replacePath, query: route.query })
}

function startRenameWorkshop() {
  if (!workshop.value) return
  workshopNameDraft.value = workshop.value.name
  editingName.value = true
}

function cancelRenameWorkshop() {
  editingName.value = false
  workshopNameDraft.value = ''
}

async function saveWorkshopName() {
  if (!workshop.value) return
  const name = workshopNameDraft.value.trim()
  if (!name) {
    ElMessage.warning('车间名称不能为空')
    return
  }
  if (name === workshop.value.name) {
    cancelRenameWorkshop()
    return
  }
  savingWorkshopName.value = true
  try {
    await map.renameWorkshop(workshop.value.id, name)
    ElMessage.success('车间名称已保存')
    cancelRenameWorkshop()
  } finally {
    savingWorkshopName.value = false
  }
}
</script>
