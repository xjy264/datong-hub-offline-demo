export function passwordValidationMessage(password: string, confirmPassword: string) {
  if (!password) return '密码不能为空'
  if (!confirmPassword) return '确认密码不能为空'
  if (password !== confirmPassword) return '两次输入的密码不一致'
  if (password.length < 8 || password.length > 20) return '密码长度需为 8-20 位'
  const missing: string[] = []
  if (!/[A-Z]/.test(password)) missing.push('大写字母')
  if (!/[a-z]/.test(password)) missing.push('小写字母')
  if (!/[0-9]/.test(password)) missing.push('数字')
  if (!/[!-/:-@[-`{-~]/.test(password)) missing.push('特殊符号')
  return missing.length ? `密码缺少${missing.join('、')}` : ''
}
