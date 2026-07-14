<template>
  <div class="app-shell">
    <header class="topbar">
      <div class="brand" @click="$router.push('/maps')">
        <h1>大同房建公寓段管辖示意图</h1>
      </div>
      <div class="top-actions">
        <el-button type="danger" plain @click="logout">退出登录</el-button>
      </div>
    </header>
    <main class="view-root">
      <router-view />
    </main>
  </div>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const auth = useAuthStore()

async function logout() {
  await auth.logout()
  router.push('/login')
}
</script>
