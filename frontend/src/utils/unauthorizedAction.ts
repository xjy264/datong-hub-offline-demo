export function unauthorizedSessionAction(pathname: string, silentRequest: boolean) {
  const redirectToLogin = !['/login', '/register'].includes(pathname)
  return {
    clearLocalSession: true,
    redirectToLogin,
    loginUrl: redirectToLogin ? '/login?reason=expired' : null,
    showMessage: !redirectToLogin && !silentRequest
  }
}
