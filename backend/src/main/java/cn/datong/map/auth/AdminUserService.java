package cn.datong.map.auth;

import cn.datong.map.common.BusinessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;

@Service
public class AdminUserService {
    private static final Set<String> APPROVAL_STATES = Set.of("PENDING", "APPROVED", "REJECTED");
    private static final Set<String> ACCOUNT_STATES = Set.of("ENABLED", "DISABLED");
    private final JdbcTemplate jdbcTemplate;
    private final PasswordEncoder passwordEncoder;

    public AdminUserService(JdbcTemplate jdbcTemplate, PasswordEncoder passwordEncoder) {
        this.jdbcTemplate = jdbcTemplate;
        this.passwordEncoder = passwordEncoder;
    }

    public List<AdminUserView> listUsers() {
        return jdbcTemplate.query("""
                SELECT id, username, real_name, phone, status, approval_status, is_super_admin, last_login_time, created_at
                FROM sys_user WHERE deleted = 0 ORDER BY is_super_admin DESC, created_at, id
                """, (rs, rowNum) -> new AdminUserView(rs.getLong("id"), rs.getString("username"),
                rs.getString("real_name"), rs.getString("phone"), rs.getString("status"),
                rs.getString("approval_status"), rs.getBoolean("is_super_admin"),
                rs.getObject("last_login_time", LocalDateTime.class), rs.getObject("created_at", LocalDateTime.class)));
    }

    @Transactional
    public void updateApproval(long userId, String approvalStatus) {
        String value = normalize(approvalStatus);
        if (!APPROVAL_STATES.contains(value)) throw new BusinessException("审核状态不正确");
        updateExisting("UPDATE sys_user SET approval_status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND deleted = 0", value, userId);
    }

    @Transactional
    public void updateStatus(long userId, String status) {
        String value = normalize(status);
        if (!ACCOUNT_STATES.contains(value)) throw new BusinessException("账号状态不正确");
        updateExisting("UPDATE sys_user SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND deleted = 0", value, userId);
    }

    @Transactional
    public void resetPassword(long userId, String password, String confirmPassword) {
        PasswordPolicy.validate(password, confirmPassword);
        updateExisting("UPDATE sys_user SET password = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND deleted = 0",
                passwordEncoder.encode(password), userId);
    }

    private void updateExisting(String sql, Object value, long userId) {
        if (jdbcTemplate.update(sql, value, userId) == 0) throw new BusinessException("用户不存在");
    }

    private String normalize(String value) {
        return value == null ? "" : value.trim().toUpperCase();
    }

    public record AdminUserView(long id, String username, String realName, String phone, String status,
                                String approvalStatus, boolean superAdmin, LocalDateTime lastLoginTime,
                                LocalDateTime createdAt) {
    }
}
