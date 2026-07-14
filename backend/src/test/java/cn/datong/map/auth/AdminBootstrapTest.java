package cn.datong.map.auth;

import org.h2.jdbcx.JdbcDataSource;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class AdminBootstrapTest {
    private JdbcTemplate jdbc;
    private BCryptPasswordEncoder encoder;

    @BeforeEach
    void setUp() {
        JdbcDataSource dataSource = new JdbcDataSource();
        dataSource.setURL("jdbc:h2:mem:" + System.nanoTime() + ";MODE=MySQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1");
        jdbc = new JdbcTemplate(dataSource);
        jdbc.execute("CREATE TABLE sys_user (id BIGINT PRIMARY KEY, username VARCHAR(64), password VARCHAR(255), phone VARCHAR(32), status VARCHAR(32), approval_status VARCHAR(32), is_super_admin TINYINT, deleted TINYINT, updated_at DATETIME)");
        jdbc.update("INSERT INTO sys_user VALUES (1, 'admin', ?, '00000000000', 'ENABLED', 'APPROVED', 1, 0, CURRENT_TIMESTAMP)", AdminBootstrap.KNOWN_DEFAULT_HASH);
        encoder = new BCryptPasswordEncoder();
    }

    @Test
    void productionRejectsKnownDefaultWithoutBootstrapSecret() {
        AdminBootstrap bootstrap = new AdminBootstrap(jdbc, encoder, true, true, "", "");
        assertThatThrownBy(bootstrap::run).hasMessage("生产环境必须配置 BOOTSTRAP_ADMIN_PHONE 和 BOOTSTRAP_ADMIN_PASSWORD");
    }

    @Test
    void productionRotatesKnownDefaultPassword() throws Exception {
        new AdminBootstrap(jdbc, encoder, true, true, "13800138000", "New1!pass").run();
        assertThat(jdbc.queryForObject("SELECT phone FROM sys_user WHERE id = 1", String.class)).isEqualTo("13800138000");
        assertThat(encoder.matches("New1!pass", jdbc.queryForObject("SELECT password FROM sys_user WHERE id = 1", String.class))).isTrue();
    }

    @Test
    void productionRejectsInsecureAuthCookie() {
        assertThatThrownBy(() -> new AdminBootstrap(jdbc, encoder, true, false, "13800138000", "New1!pass").run())
                .hasMessage("生产环境必须启用 AUTH_COOKIE_SECURE");
    }
}
