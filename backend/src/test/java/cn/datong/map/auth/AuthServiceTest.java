package cn.datong.map.auth;

import cn.datong.map.common.BusinessException;
import cn.datong.map.security.JwtTokenProvider;
import org.h2.jdbcx.JdbcDataSource;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class AuthServiceTest {
    private JdbcTemplate jdbc;
    private AuthService service;

    @BeforeEach
    void setUp() {
        JdbcDataSource dataSource = new JdbcDataSource();
        dataSource.setURL("jdbc:h2:mem:" + System.nanoTime() + ";MODE=MySQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1");
        jdbc = new JdbcTemplate(dataSource);
        jdbc.execute("CREATE TABLE sys_user (id BIGINT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(64) NOT NULL UNIQUE, password VARCHAR(255) NOT NULL, real_name VARCHAR(64) NOT NULL, phone VARCHAR(32), status VARCHAR(32) NOT NULL DEFAULT 'ENABLED', approval_status VARCHAR(32) NOT NULL DEFAULT 'APPROVED', is_super_admin TINYINT(1) NOT NULL DEFAULT 0, last_login_time DATETIME NULL, created_at DATETIME, updated_at DATETIME, deleted TINYINT(1) NOT NULL DEFAULT 0)");
        service = new AuthService(jdbc, new BCryptPasswordEncoder(), new JwtTokenProvider("01234567890123456789012345678901", 86400));
    }

    @Test
    void registerCreatesPendingNonAdminUser() {
        service.register(new RegisterRequest("张三", "13800138000", "Aa1!aaaa", "Aa1!aaaa"));

        assertThat(jdbc.queryForObject("SELECT status FROM sys_user WHERE phone = '13800138000'", String.class)).isEqualTo("ENABLED");
        assertThat(jdbc.queryForObject("SELECT approval_status FROM sys_user WHERE phone = '13800138000'", String.class)).isEqualTo("PENDING");
        assertThat(jdbc.queryForObject("SELECT is_super_admin FROM sys_user WHERE phone = '13800138000'", Integer.class)).isZero();
        assertThatThrownBy(() -> service.login(new LoginRequest("13800138000", "Aa1!aaaa")))
                .isInstanceOf(BusinessException.class)
                .hasMessage("账号待管理员审核");

        jdbc.update("UPDATE sys_user SET approval_status = 'APPROVED' WHERE phone = '13800138000'");
        AuthService.LoginResult result = service.login(new LoginRequest("13800138000", "Aa1!aaaa"));
        assertThat(result.session().user().phone()).isEqualTo("13800138000");
        assertThat(result.session().user().realName()).isEqualTo("张三");
        assertThat(result.session().user().isSuperAdmin()).isFalse();
        assertThat(result.session().permissions()).containsExactly("MAP_EDIT");
    }

    @Test
    void registerRejectsDuplicatePhone() {
        service.register(new RegisterRequest("张三", "13800138000", "Aa1!aaaa", "Aa1!aaaa"));

        assertThatThrownBy(() -> service.register(new RegisterRequest("李四", "13800138000", "Aa1!bbbb", "Aa1!bbbb")))
                .isInstanceOf(BusinessException.class)
                .hasMessage("手机号已存在");
    }

    @Test
    void registerRejectsInvalidNamePhoneAndPassword() {
        assertThatThrownBy(() -> service.register(new RegisterRequest("tom", "13800138000", "Aa1!aaaa", "Aa1!aaaa")))
                .isInstanceOf(BusinessException.class)
                .hasMessage("真实姓名需为2-10位中文或中间点");
        assertThatThrownBy(() -> service.register(new RegisterRequest("张三", "123", "Aa1!aaaa", "Aa1!aaaa")))
                .isInstanceOf(BusinessException.class)
                .hasMessage("请输入正确的手机号");
        assertThatThrownBy(() -> service.register(new RegisterRequest("张三", "13800138000", "weakpass", "weakpass")))
                .isInstanceOf(BusinessException.class)
                .hasMessage("密码缺少大写字母、数字、特殊符号");
    }
}
