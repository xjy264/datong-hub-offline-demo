package cn.datong.map.auth;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ProductionSecurityGuardTest {
    @Test
    void productionRejectsInsecureAuthCookie() {
        ProductionSecurityGuard guard = new ProductionSecurityGuard(true, false);

        assertThatThrownBy(() -> guard.run(null)).hasMessage("生产环境必须启用 AUTH_COOKIE_SECURE");
    }

    @Test
    void secureProductionAndLocalDevelopmentCanStart() {
        assertThatCode(() -> new ProductionSecurityGuard(true, true).run(null)).doesNotThrowAnyException();
        assertThatCode(() -> new ProductionSecurityGuard(false, false).run(null)).doesNotThrowAnyException();
    }
}
