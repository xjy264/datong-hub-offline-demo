<template>
  <section class="page" v-loading="map.loading">
    <div class="page-head">
      <div class="head-main">
        <div>
          <div class="eyebrow">地图选择</div>
          <h2 class="page-title">请选择要查看的地图</h2>
          <p class="subline">选择地图查看，也可上传、改名、删除地图。</p>
        </div>
        <el-button type="primary" @click="pdfInput?.click()">上传 PDF 新增地图</el-button>
        <input ref="pdfInput" class="file-input" type="file" accept="application/pdf,.pdf" @change="uploadPdf" />
      </div>
    </div>

    <section class="map-select-grid">
      <article v-for="item in map.maps" :key="item.id" class="map-select-card" @click="enterMap(item.id)">
        <img :src="item.backgroundUrl" alt="" />
        <div class="map-select-body">
          <strong>{{ item.name }}</strong>
          <span>{{ item.width }} × {{ item.height }}</span>
          <div class="button-row">
            <el-button size="small" @click.stop="renameMap(item.id, item.name)">改名</el-button>
            <el-button size="small" type="danger" plain @click.stop="deleteMap(item.id, item.name)">删除</el-button>
          </div>
        </div>
      </article>
      <div v-if="!map.maps.length" class="empty">暂无地图，请上传 PDF。</div>
    </section>
  </section>
</template>

<script setup lang="ts">
import { ElMessage, ElMessageBox } from 'element-plus'
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useMapStore } from '../stores/map'

const map = useMapStore()
const router = useRouter()
const pdfInput = ref<HTMLInputElement | null>(null)

onMounted(() => map.load())

async function enterMap(mapId: string) {
  await map.loadMap(mapId)
  router.push({ path: '/map', query: { mapId } })
}

async function uploadPdf(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return
  const name = await ElMessageBox.prompt('请输入地图名称', '上传背景 PDF', { inputValue: file.name.replace(/\.pdf$/i, '') }).then((result) => result.value).catch(() => '')
  input.value = ''
  if (!name) return
  await map.createMap(name, file)
  ElMessage.success('已创建新地图')
  if (map.currentMap) await enterMap(map.currentMap.id)
}

async function renameMap(mapId: string, currentName: string) {
  const name = await ElMessageBox.prompt('请输入地图名称', '修改地图名称', { inputValue: currentName }).then((result) => result.value).catch(() => '')
  if (!name) return
  await map.renameMap(mapId, name)
  ElMessage.success('已修改地图名称')
}

async function deleteMap(mapId: string, name: string) {
  const confirmed = await ElMessageBox.confirm(`确定删除“${name}”吗？关联的车站按钮也会删除。`, '删除地图', {
    confirmButtonText: '确认删除',
    cancelButtonText: '取消',
    type: 'warning'
  }).then(() => true).catch(() => false)
  if (!confirmed) return
  await map.deleteMap(mapId)
  ElMessage.success('已删除地图')
}
</script>
