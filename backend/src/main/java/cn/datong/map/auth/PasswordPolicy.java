package cn.datong.map.auth;

import cn.datong.map.common.BusinessException;

import java.util.ArrayList;
import java.util.List;

public final class PasswordPolicy {
    private PasswordPolicy() {
    }

    public static void validate(String password, String confirmPassword) {
        if (password == null || password.isBlank()) throw new BusinessException("密码不能为空");
        if (confirmPassword == null || confirmPassword.isBlank()) throw new BusinessException("确认密码不能为空");
        if (!password.equals(confirmPassword)) throw new BusinessException("两次输入的密码不一致");
        if (password.length() < 8 || password.length() > 20) throw new BusinessException("密码长度需为 8-20 位");
        List<String> missing = new ArrayList<>();
        boolean upper = false, lower = false, digit = false, special = false;
        for (int i = 0; i < password.length(); i++) {
            char ch = password.charAt(i);
            upper |= ch >= 'A' && ch <= 'Z';
            lower |= ch >= 'a' && ch <= 'z';
            digit |= ch >= '0' && ch <= '9';
            special |= (ch >= 33 && ch <= 47) || (ch >= 58 && ch <= 64) || (ch >= 91 && ch <= 96) || (ch >= 123 && ch <= 126);
        }
        if (!upper) missing.add("大写字母");
        if (!lower) missing.add("小写字母");
        if (!digit) missing.add("数字");
        if (!special) missing.add("特殊符号");
        if (!missing.isEmpty()) throw new BusinessException("密码缺少" + String.join("、", missing));
    }
}
