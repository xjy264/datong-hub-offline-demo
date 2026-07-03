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
        <SliderCaptcha
          ref="captchaRef"
          host-id="login-captcha"
          :verified="Boolean(form.captchaKey)"
          unavailable-message="人机验证暂时不可用，请稍后重试或联系管理员。"
          @verified="handleCaptchaVerified"
          @reset="resetCaptchaState"
        />
        <el-button type="primary" style="width:100%" :loading="loading" @click="login">登录</el-button>
      </el-form>
    </section>
  </div>
</template>

<script setup lang="ts">
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { apiPost } from '../api/http'
import SliderCaptcha from '../components/SliderCaptcha.vue'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const auth = useAuthStore()
const loading = ref(false)
const captchaRef = ref<InstanceType<typeof SliderCaptcha> | null>(null)
const REMEMBER_PHONE_KEY = 'datong-map:remember-phone'
const rememberedPhone = localStorage.getItem(REMEMBER_PHONE_KEY) || ''
const rememberPhone = ref(Boolean(rememberedPhone))
const form = reactive({ phone: rememberedPhone, password: '', captchaKey: '', captchaCode: '' })

function resetCaptchaState() {
  form.captchaKey = ''
  form.captchaCode = ''
}

function handleCaptchaVerified(payload: { captchaKey: string; captchaCode: string }) {
  form.captchaKey = payload.captchaKey
  form.captchaCode = payload.captchaCode
}

async function login() {
  if (!form.captchaKey) {
    captchaRef.value?.setError('请先完成滑块验证。')
    return
  }
  loading.value = true
  try {
    const result = await apiPost<{ user: any; permissions: string[] }>('/auth/login', form)
    if (rememberPhone.value) localStorage.setItem(REMEMBER_PHONE_KEY, form.phone.trim())
    else localStorage.removeItem(REMEMBER_PHONE_KEY)
    auth.setSession(result.user, result.permissions)
    router.push('/map')
  } catch {
    captchaRef.value?.reset()
  } finally {
    loading.value = false
  }
}
</script>
