package cn.datong.map.auth;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class AdminBootstrap implements ApplicationRunner {
    static final String KNOWN_DEFAULT_HASH = "$2y$10$JLYTEoDd2O7bkkA9W176He7tuLuAMKNQ4baclBgz02t4mD8FO3joW";
    private final JdbcTemplate jdbcTemplate;
    private final PasswordEncoder passwordEncoder;
    private final boolean production;
    private final boolean cookieSecure;
    private final String phone;
    private final String password;

    public AdminBootstrap(JdbcTemplate jdbcTemplate, PasswordEncoder passwordEncoder,
                          @Value("${app.production:false}") boolean production,
                          @Value("${app.auth.cookie-secure:false}") boolean cookieSecure,
                          @Value("${app.bootstrap-admin.phone:}") String phone,
                          @Value("${app.bootstrap-admin.password:}") String password) {
        this.jdbcTemplate = jdbcTemplate;
        this.passwordEncoder = passwordEncoder;
        this.production = production;
        this.cookieSecure = cookieSecure;
        this.phone = phone == null ? "" : phone.trim();
        this.password = password == null ? "" : password;
    }

    @Override
    public void run(ApplicationArguments args) {
        run();
    }

    public void run() {
        if (!production) return;
        if (!cookieSecure) throw new IllegalStateException("生产环境必须启用 AUTH_COOKIE_SECURE");
        List<AdminRow> admins = jdbcTemplate.query("""
                SELECT id, password FROM sys_user
                WHERE is_super_admin = 1 AND deleted = 0 ORDER BY id LIMIT 1
                """, (rs, rowNum) -> new AdminRow(rs.getLong("id"), rs.getString("password")));
        if (admins.isEmpty() || KNOWN_DEFAULT_HASH.equals(admins.getFirst().passwordHash())) {
            if (phone.isBlank() || password.isBlank()) {
                throw new IllegalStateException("生产环境必须配置 BOOTSTRAP_ADMIN_PHONE 和 BOOTSTRAP_ADMIN_PASSWORD");
            }
            String validPhone = UserInputValidator.phone(phone);
            PasswordPolicy.validate(password, password);
            if (admins.isEmpty()) {
                jdbcTemplate.update("""
                        INSERT INTO sys_user (username, password, real_name, phone, status, approval_status, is_super_admin, deleted, created_at, updated_at)
                        VALUES (?, ?, '系统管理员', ?, 'ENABLED', 'APPROVED', 1, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        """, validPhone, passwordEncoder.encode(password), validPhone);
            } else {
                jdbcTemplate.update("""
                        UPDATE sys_user SET username = ?, phone = ?, password = ?, status = 'ENABLED',
                        approval_status = 'APPROVED', updated_at = CURRENT_TIMESTAMP WHERE id = ?
                        """, validPhone, validPhone, passwordEncoder.encode(password), admins.getFirst().id());
            }
        }
    }

    private record AdminRow(long id, String passwordHash) {
    }
}
