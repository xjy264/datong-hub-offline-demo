<template>
  <div class="app-shell">
    <header class="topbar">
      <div class="brand" @click="$router.push('/map')">
        <h1>大同房建公寓段管辖示意图</h1>
        <span class="status">{{ auth.user?.realName || '已登录' }} · 数据保存在服务器</span>
      </div>
      <div class="top-actions">
        <el-button @click="triggerImport">导入旧数据</el-button>
        <el-button @click="exportData">导出数据</el-button>
        <el-button type="danger" plain @click="logout">退出登录</el-button>
        <input ref="importInput" class="file-input" type="file" accept="application/json,.json" @change="importData" />
      </div>
    </header>
    <main class="view-root">
      <router-view />
    </main>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { apiGet } from '../api/http'
import { useAuthStore } from '../stores/auth'
import { useMapStore } from '../stores/map'

const router = useRouter()
const auth = useAuthStore()
const map = useMapStore()
const importInput = ref<HTMLInputElement | null>(null)

function triggerImport() {
  importInput.value?.click()
}

async function importData(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return
  await map.importJson(file)
  input.value = ''
  ElMessage.success('已导入数据')
}

async function exportData() {
  const payload = await apiGet<Record<string, unknown>>('/export')
  const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = 'datong-map-data.json'
  link.click()
  URL.revokeObjectURL(url)
}

async function logout() {
  await auth.logout()
  router.push('/login')
}
</script>
