package cn.datong.map.auth;

import cn.datong.map.common.BusinessException;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class PasswordPolicyTest {
    @Test
    void acceptsStrongPassword() {
        assertThatCode(() -> PasswordPolicy.validate("Aa1!aaaa", "Aa1!aaaa")).doesNotThrowAnyException();
    }

    @Test
    void rejectsBlankAndMismatchedPasswords() {
        assertThatThrownBy(() -> PasswordPolicy.validate("", "Aa1!aaaa"))
                .isInstanceOf(BusinessException.class).hasMessage("密码不能为空");
        assertThatThrownBy(() -> PasswordPolicy.validate("Aa1!aaaa", ""))
                .isInstanceOf(BusinessException.class).hasMessage("确认密码不能为空");
        assertThatThrownBy(() -> PasswordPolicy.validate("Aa1!aaaa", "Aa1!aaab"))
                .isInstanceOf(BusinessException.class).hasMessage("两次输入的密码不一致");
    }

    @Test
    void rejectsLengthAndMissingRules() {
        assertThatThrownBy(() -> PasswordPolicy.validate("Aa1!", "Aa1!"))
                .isInstanceOf(BusinessException.class).hasMessage("密码长度需为 8-20 位");
        assertThatThrownBy(() -> PasswordPolicy.validate("aa1!aaaa", "aa1!aaaa"))
                .isInstanceOf(BusinessException.class).hasMessage("密码缺少大写字母");
        assertThatThrownBy(() -> PasswordPolicy.validate("AA1!AAAA", "AA1!AAAA"))
                .isInstanceOf(BusinessException.class).hasMessage("密码缺少小写字母");
        assertThatThrownBy(() -> PasswordPolicy.validate("Aaa!aaaa", "Aaa!aaaa"))
                .isInstanceOf(BusinessException.class).hasMessage("密码缺少数字");
        assertThatThrownBy(() -> PasswordPolicy.validate("Aa11aaaa", "Aa11aaaa"))
                .isInstanceOf(BusinessException.class).hasMessage("密码缺少特殊符号");
    }
}
