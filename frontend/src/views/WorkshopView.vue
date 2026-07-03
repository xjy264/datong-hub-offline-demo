<template>
  <section class="page workshop-page" v-loading="map.loading">
    <div class="page-head">
      <div class="crumbs">
        <el-button text @click="router.push('/map')">地图</el-button>
        <span class="crumb current">{{ workshop.name }}</span>
      </div>
      <div class="head-main">
        <div>
          <div class="eyebrow">车间页面</div>
          <h2 class="page-title">{{ workshop.name }}</h2>
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
        <button v-for="station in filteredStations" :key="station.id" class="station-row" :class="{ focused: station.id === focusId }" @click="router.push(`/stations/${station.id}`)">
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
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { WORKSHOPS } from '../constants/workshops'
import { useMapStore } from '../stores/map'
import type { StationFolder } from '../types'

const route = useRoute()
const router = useRouter()
const map = useMapStore()
const query = ref('')
const colorFilter = ref('all')
const focusId = computed(() => String(route.query.focus || ''))
const workshop = computed(() => WORKSHOPS.find((item) => item.id === route.params.id) || WORKSHOPS[0])
const stationList = computed(() => map.stations.filter((station) => station.workshopId === workshop.value.id).sort((a, b) => a.position.y - b.position.y || a.position.x - b.position.x))
const filteredStations = computed(() => {
  const text = query.value.trim().toLowerCase()
  return stationList.value.filter((station) => {
    const colorOk = colorFilter.value === 'all' || station.color === colorFilter.value
    const haystack = `${station.name} ${station.autoName} ${station.mileage}`.toLowerCase()
    return colorOk && (!text || haystack.includes(text))
  })
})

onMounted(() => map.load())

function countImages(folders: StationFolder[]): number {
  return folders.reduce((sum, folder) => sum + folder.images.length + countImages(folder.children), 0)
}
</script>
