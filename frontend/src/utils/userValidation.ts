const REAL_NAME_PATTERN = /^[\u4e00-\u9fa5·]{2,10}$/
const PHONE_PATTERN = /^1[3-9]\d{9}$/

export function normalizeRegisterRealName(realName: string) {
  const normalized = realName.trim()
  return REAL_NAME_PATTERN.test(normalized) ? normalized : ''
}

export function normalizeRegisterPhone(phone: string) {
  const normalized = phone.trim()
  return PHONE_PATTERN.test(normalized) ? normalized : ''
}
