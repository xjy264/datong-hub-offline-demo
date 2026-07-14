package cn.datong.map.auth;

import org.h2.jdbcx.JdbcDataSource;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class AdminUserServiceTest {
    private JdbcTemplate jdbc;
    private BCryptPasswordEncoder encoder;
    private AdminUserService service;

    @BeforeEach
    void setUp() {
        JdbcDataSource dataSource = new JdbcDataSource();
        dataSource.setURL("jdbc:h2:mem:" + System.nanoTime() + ";MODE=MySQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1");
        jdbc = new JdbcTemplate(dataSource);
        jdbc.execute("CREATE TABLE sys_user (id BIGINT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(64), password VARCHAR(255), real_name VARCHAR(64), phone VARCHAR(32), status VARCHAR(32), approval_status VARCHAR(32), is_super_admin TINYINT, last_login_time DATETIME, created_at DATETIME, updated_at DATETIME, deleted TINYINT)");
        encoder = new BCryptPasswordEncoder();
        jdbc.update("INSERT INTO sys_user (username,password,real_name,phone,status,approval_status,is_super_admin,created_at,updated_at,deleted) VALUES ('13800138000',?,'张三','13800138000','ENABLED','PENDING',0,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,0)", encoder.encode("Old1!pass"));
        service = new AdminUserService(jdbc, encoder);
    }

    @Test
    void listsAndApprovesPendingUser() {
        AdminUserService.AdminUserView pending = service.listUsers().getFirst();
        assertThat(pending.approvalStatus()).isEqualTo("PENDING");

        service.updateApproval(pending.id(), "APPROVED");

        assertThat(service.listUsers().getFirst().approvalStatus()).isEqualTo("APPROVED");
    }

    @Test
    void disablesUserAndResetsPassword() {
        long id = service.listUsers().getFirst().id();
        service.updateStatus(id, "DISABLED");
        service.resetPassword(id, "New1!pass", "New1!pass");

        assertThat(service.listUsers().getFirst().status()).isEqualTo("DISABLED");
        assertThat(encoder.matches("New1!pass", jdbc.queryForObject("SELECT password FROM sys_user WHERE id = ?", String.class, id))).isTrue();
    }

    @Test
    void rejectsUnknownAdminStateValues() {
        long id = service.listUsers().getFirst().id();
        assertThatThrownBy(() -> service.updateApproval(id, "ROOT")).hasMessage("审核状态不正确");
        assertThatThrownBy(() -> service.updateStatus(id, "LOCKED")).hasMessage("账号状态不正确");
    }
}
