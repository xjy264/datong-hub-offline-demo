export function unauthorizedSessionAction(pathname: string) {
  const redirectToLogin = !['/login', '/register'].includes(pathname)
  return {
    clearLocalSession: true,
    redirectToLogin,
    loginUrl: redirectToLogin ? '/login?reason=expired' : null
  }
}
