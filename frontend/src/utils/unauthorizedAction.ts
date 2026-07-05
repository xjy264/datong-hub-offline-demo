export function unauthorizedSessionAction(pathname: string) {
  return {
    clearLocalSession: true,
    redirectToLogin: pathname !== '/login'
  }
}
