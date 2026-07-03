import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import LoginView from '../views/LoginView.vue'
import LayoutView from '../views/LayoutView.vue'
import MapSelectView from '../views/MapSelectView.vue'
import MapView from '../views/MapView.vue'
import WorkshopView from '../views/WorkshopView.vue'
import StationView from '../views/StationView.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/login', component: LoginView },
    {
      path: '/',
      component: LayoutView,
      redirect: '/maps',
      children: [
        { path: 'maps', component: MapSelectView },
        { path: 'map', component: MapView },
        { path: 'workshops/:id', component: WorkshopView },
        { path: 'stations/:name/:id', component: StationView },
        { path: 'stations/:id', component: StationView }
      ]
    }
  ]
})

router.beforeEach(async (to) => {
  const auth = useAuthStore()
  await auth.restoreSession()
  if (!auth.isAuthenticated && to.path !== '/login') return '/login'
  if (auth.isAuthenticated && to.path === '/login') return '/maps'
  return true
})

export default router
