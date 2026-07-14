package cn.datong.map.auth;

import jakarta.validation.constraints.NotBlank;

public record RegisterRequest(
        @NotBlank(message = "真实姓名不能为空") String realName,
        @NotBlank(message = "手机号不能为空") String phone,
        String password,
        String confirmPassword
) {
}
