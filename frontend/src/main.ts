import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'
import router from './router'
import 'element-plus/theme-chalk/el-message.css'
import './styles/main.css'
import { isHandledApiError } from './utils/actionFeedback'

const app = createApp(App)
app.config.errorHandler = (error) => {
  if (!isHandledApiError(error)) console.error(error)
}
app.use(createPinia()).use(router).mount('#app')
