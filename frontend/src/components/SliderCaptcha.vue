<template>
  <el-alert v-if="errorMessage" :title="errorMessage" type="warning" :closable="false" show-icon style="margin-bottom: 14px" />
  <el-form-item label="人机验证">
    <div class="slider-captcha-wrapper">
      <div class="slider-captcha-row">
        <el-button :type="verified ? 'success' : 'primary'" plain :disabled="captchaDisabled" @click="openCaptcha">
          {{ buttonText }}
        </el-button>
        <el-button text :disabled="captchaDisabled" @click="reset">重新验证</el-button>
      </div>
      <div :id="hostId" class="slider-captcha-host"></div>
    </div>
  </el-form-item>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

interface CaptchaVerifiedPayload {
  captchaKey: string
  captchaCode: string
}

declare global {
  interface Window {
    TAC?: new (config: Record<string, unknown>, style?: Record<string, unknown>) => {
      init: () => void
      destroyWindow: () => void
      config?: { doSendRequest?: (request: Record<string, unknown>) => Promise<unknown> }
    }
  }
}

const props = defineProps<{ hostId: string; verified: boolean; unavailableMessage: string }>()
const emit = defineEmits<{ (e: 'verified', payload: CaptchaVerifiedPayload): void; (e: 'reset'): void }>()
const errorMessage = ref('')
const captchaDisabled = computed(() => String(import.meta.env.VITE_CAPTCHA_PROVIDER || 'none').toLowerCase() === 'none')
const buttonText = computed(() => captchaDisabled.value ? '本地开发已跳过验证' : (props.verified ? '验证已通过' : '点击完成滑块验证'))
let captchaInstance: InstanceType<NonNullable<typeof window.TAC>> | undefined

async function openCaptcha() {
  errorMessage.value = ''
  if (captchaDisabled.value) {
    emit('verified', { captchaKey: 'CAPTCHA_DISABLED', captchaCode: 'SLIDER_PASSED' })
    return
  }
  if (!window.TAC) {
    errorMessage.value = props.unavailableMessage
    return
  }
  captchaInstance?.destroyWindow()
  captchaInstance = new window.TAC({
    bindEl: `#${props.hostId}`,
    requestCaptchaDataUrl: '/api/auth/captcha',
    validCaptchaUrl: '/api/auth/captcha/check',
    validSuccess: (result: any) => {
      emit('verified', { captchaKey: result?.data?.captchaKey || '', captchaCode: result?.data?.captchaCode || '' })
      captchaInstance?.destroyWindow()
    },
    validFail: () => {
      reset()
      errorMessage.value = '滑块验证未通过，请重新验证。'
    }
  }, { logoUrl: null, i18n: { slider_title: '拖动滑块完成验证' } })
  captchaInstance.init()
}

function reset() {
  captchaInstance?.destroyWindow()
  captchaInstance = undefined
  emit('reset')
  if (captchaDisabled.value) emit('verified', { captchaKey: 'CAPTCHA_DISABLED', captchaCode: 'SLIDER_PASSED' })
}

function setError(message: string) {
  errorMessage.value = message
}

onMounted(reset)
onBeforeUnmount(() => captchaInstance?.destroyWindow())
defineExpose({ reset, setError })
</script>

<style scoped>
.slider-captcha-wrapper { position: relative; width: 100%; }
.slider-captcha-row { display: flex; gap: 8px; width: 100%; }
.slider-captcha-row .el-button:first-child { flex: 1; }
.slider-captcha-host { position: absolute; bottom: calc(100% + 10px); left: 50%; z-index: 3000; width: 318px; max-width: calc(100vw - 24px); transform: translateX(-50%); }
.slider-captcha-host:empty { display: none; }
</style>
