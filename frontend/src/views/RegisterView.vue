<template>
  <div class="auth-page">
    <section class="auth-brand">
      <h1>账号注册</h1>
      <p>注册成功后即可登录使用。</p>
    </section>
    <section class="auth-panel">
      <h2>注册账号</h2>
      <el-form label-position="top" @submit.prevent>
        <el-form-item label="真实姓名"><el-input v-model="form.realName" maxlength="10" autocomplete="name" /></el-form-item>
        <el-form-item label="手机号"><el-input v-model="form.phone" maxlength="11" autocomplete="tel" /></el-form-item>
        <el-form-item label="密码"><el-input v-model="form.password" type="password" show-password autocomplete="new-password" /></el-form-item>
        <el-form-item label="确认密码"><el-input v-model="form.confirmPassword" type="password" show-password autocomplete="new-password" /></el-form-item>
        <el-button type="primary" style="width:100%" :loading="loading" @click="submit">注册</el-button>
        <el-button text style="width:100%;margin:10px 0 0" @click="router.push('/login')">返回登录</el-button>
      </el-form>
    </section>
  </div>
</template>

<script setup lang="ts">
import { ElMessage } from 'element-plus'
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { apiPost } from '../api/http'
import { passwordValidationMessage } from '../utils/passwordPolicy'
import { normalizeRegisterPhone, normalizeRegisterRealName } from '../utils/userValidation'

const router = useRouter()
const loading = ref(false)
const form = reactive({ realName: '', phone: '', password: '', confirmPassword: '' })

async function submit() {
  const realName = normalizeRegisterRealName(form.realName)
  if (!realName) return ElMessage.warning('真实姓名需为2-10位中文或中间点')
  const phone = normalizeRegisterPhone(form.phone)
  if (!phone) return ElMessage.warning('请输入正确的手机号')
  const passwordMessage = passwordValidationMessage(form.password, form.confirmPassword)
  if (passwordMessage) return ElMessage.warning(passwordMessage)
  loading.value = true
  try {
    await apiPost('/auth/register', { ...form, realName, phone })
    ElMessage.success('注册成功，请登录')
    router.push('/login')
  } finally {
    loading.value = false
  }
}
</script>
