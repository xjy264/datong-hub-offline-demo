package cn.datong.map.auth;

import cn.datong.map.common.BusinessException;

import java.util.regex.Pattern;

public final class UserInputValidator {
    private static final Pattern REAL_NAME = Pattern.compile("^[\\u4e00-\\u9fa5·]{2,10}$");
    private static final Pattern PHONE = Pattern.compile("^1[3-9]\\d{9}$");

    private UserInputValidator() {
    }

    public static String realName(String value) {
        String normalized = trim(value);
        if (!REAL_NAME.matcher(normalized).matches()) throw new BusinessException("真实姓名需为2-10位中文或中间点");
        return normalized;
    }

    public static String phone(String value) {
        String normalized = trim(value);
        if (!PHONE.matcher(normalized).matches()) throw new BusinessException("请输入正确的手机号");
        return normalized;
    }

    private static String trim(String value) {
        return value == null ? "" : value.trim();
    }
}
