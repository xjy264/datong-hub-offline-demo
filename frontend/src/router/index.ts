import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const LoginView = () => import('../views/LoginView.vue')
const RegisterView = () => import('../views/RegisterView.vue')
const LayoutView = () => import('../views/LayoutView.vue')
const MapSelectView = () => import('../views/MapSelectView.vue')
const MapView = () => import('../views/MapView.vue')
const WorkshopView = () => import('../views/WorkshopView.vue')
const StationView = () => import('../views/StationView.vue')
const AdminUsersView = () => import('../views/AdminUsersView.vue')

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/login', component: LoginView },
    { path: '/register', component: RegisterView },
    {
      path: '/',
      component: LayoutView,
      redirect: '/maps',
      children: [
        { path: 'maps', component: MapSelectView },
        { path: 'map', component: MapView },
        { path: 'workshops/:id', component: WorkshopView },
        { path: 'stations/:name/:id', component: StationView },
        { path: 'stations/:id', component: StationView },
        { path: 'admin/users', component: AdminUsersView, meta: { userAdmin: true } }
      ]
    }
  ]
})

router.beforeEach(async (to) => {
  const auth = useAuthStore()
  await auth.restoreSession()
  const publicAuthPage = to.path === '/login' || to.path === '/register'
  if (!auth.isAuthenticated && !publicAuthPage) return '/login'
  if (auth.isAuthenticated && publicAuthPage) return '/maps'
  if (to.meta.userAdmin && !auth.canManageUsers) return '/maps'
  return true
})

export default router
