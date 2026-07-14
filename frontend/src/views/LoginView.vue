<template>
  <div class="auth-page">
    <section class="auth-brand">
      <h1>大同房建公寓段管辖示意图</h1>
      <p>站点目录与图片服务端持久化管理</p>
    </section>
    <section class="auth-panel">
      <h2>用户登录</h2>
      <el-form label-position="top" @submit.prevent>
        <el-form-item label="手机号">
          <el-input v-model="form.phone" autocomplete="username" />
        </el-form-item>
        <el-form-item label="密码">
          <el-input v-model="form.password" type="password" show-password autocomplete="current-password" />
        </el-form-item>
        <el-checkbox v-model="rememberPhone" class="remember-phone">记住手机号</el-checkbox>
        <el-button type="primary" style="width:100%" :loading="loading" @click="login">登录</el-button>
        <el-button text style="width:100%;margin:10px 0 0" @click="router.push('/register')">申请注册账号</el-button>
      </el-form>
    </section>
  </div>
</template>

<script setup lang="ts">
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { apiPost } from '../api/http'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const auth = useAuthStore()
const loading = ref(false)
const REMEMBER_PHONE_KEY = 'datong-map:remember-phone'
const rememberedPhone = localStorage.getItem(REMEMBER_PHONE_KEY) || ''
const rememberPhone = ref(Boolean(rememberedPhone))
const form = reactive({ phone: rememberedPhone, password: '' })

async function login() {
  loading.value = true
  try {
    const result = await apiPost<{ user: any; permissions: string[] }>('/auth/login', form)
    if (rememberPhone.value) localStorage.setItem(REMEMBER_PHONE_KEY, form.phone.trim())
    else localStorage.removeItem(REMEMBER_PHONE_KEY)
    auth.setSession(result.user, result.permissions)
    router.push('/maps')
  } finally {
    loading.value = false
  }
}
</script>
