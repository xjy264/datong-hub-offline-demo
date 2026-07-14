<template>
  <section class="page" v-loading="loading">
    <div class="page-head">
      <div class="eyebrow">系统管理</div>
      <h2 class="page-title">用户审核与账号管理</h2>
    </div>
    <section class="panel admin-users-panel">
      <el-table :data="users" empty-text="暂无用户">
        <el-table-column prop="realName" label="姓名" />
        <el-table-column prop="phone" label="手机号" />
        <el-table-column label="审核状态">
          <template #default="{ row }">
            <el-select v-model="row.approvalStatus" :disabled="row.superAdmin" @change="updateApproval(row)">
              <el-option label="待审核" value="PENDING" />
              <el-option label="已通过" value="APPROVED" />
              <el-option label="已拒绝" value="REJECTED" />
            </el-select>
          </template>
        </el-table-column>
        <el-table-column label="账号状态">
          <template #default="{ row }">
            <el-switch v-model="row.enabled" :disabled="row.superAdmin" active-text="启用" inactive-text="禁用" @change="updateStatus(row)" />
          </template>
        </el-table-column>
        <el-table-column label="操作" width="130">
          <template #default="{ row }">
            <el-button size="small" :disabled="row.superAdmin" @click="resetPassword(row)">重置密码</el-button>
          </template>
        </el-table-column>
      </el-table>
    </section>
  </section>
</template>

<script setup lang="ts">
import { ElMessage, ElMessageBox } from 'element-plus'
import { onMounted, ref } from 'vue'
import { apiGet, apiPut } from '../api/http'

interface AdminUser {
  id: number
  username: string
  realName: string
  phone: string
  status: string
  approvalStatus: string
  superAdmin: boolean
  enabled: boolean
}

const users = ref<AdminUser[]>([])
const loading = ref(false)

async function load() {
  loading.value = true
  try {
    const result = await apiGet<Omit<AdminUser, 'enabled'>[]>('/admin/users')
    users.value = result.map((user) => ({ ...user, enabled: user.status === 'ENABLED' }))
  } finally {
    loading.value = false
  }
}

async function updateApproval(user: AdminUser) {
  await apiPut(`/admin/users/${user.id}/approval`, { value: user.approvalStatus })
  ElMessage.success('审核状态已更新')
}

async function updateStatus(user: AdminUser) {
  user.status = user.enabled ? 'ENABLED' : 'DISABLED'
  await apiPut(`/admin/users/${user.id}/status`, { value: user.status })
  ElMessage.success('账号状态已更新')
}

async function resetPassword(user: AdminUser) {
  const password = await ElMessageBox.prompt('输入符合复杂度要求的新密码', `重置 ${user.realName} 的密码`, {
    inputType: 'password',
    inputValidator: (value) => value.length >= 8 || '密码至少8位'
  }).then((result) => result.value).catch(() => '')
  if (!password) return
  await apiPut(`/admin/users/${user.id}/password`, { password, confirmPassword: password })
  ElMessage.success('密码已重置')
}

onMounted(load)
</script>
