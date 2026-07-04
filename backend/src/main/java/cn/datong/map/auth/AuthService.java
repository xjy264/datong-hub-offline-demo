package cn.datong.map.auth;

import cn.datong.map.common.BusinessException;
import cn.datong.map.security.JwtTokenProvider;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Set;

@Service
public class AuthService {
    private final JdbcTemplate jdbcTemplate;
    private final PasswordEncoder passwordEncoder;
    private final CaptchaService captchaService;
    private final JwtTokenProvider jwtTokenProvider;

    public AuthService(JdbcTemplate jdbcTemplate, PasswordEncoder passwordEncoder, CaptchaService captchaService, JwtTokenProvider jwtTokenProvider) {
        this.jdbcTemplate = jdbcTemplate;
        this.passwordEncoder = passwordEncoder;
        this.captchaService = captchaService;
        this.jwtTokenProvider = jwtTokenProvider;
    }

    @Transactional
    public void register(RegisterRequest request) {
        captchaService.verify(request.captchaKey(), request.captchaCode());
        String realName = UserInputValidator.realName(request.realName());
        String phone = UserInputValidator.phone(request.phone());
        PasswordPolicy.validate(request.password(), request.confirmPassword());
        Integer count = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM sys_user WHERE phone = ? OR username = ?", Integer.class, phone, phone);
        if (count != null && count > 0) {
            throw new BusinessException("手机号已存在");
        }
        jdbcTemplate.update("""
                INSERT INTO sys_user (username, password, real_name, phone, status, approval_status, is_super_admin, deleted, created_at, updated_at)
                VALUES (?, ?, ?, ?, 'ENABLED', 'APPROVED', 1, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                """, phone, passwordEncoder.encode(request.password()), realName, phone);
    }

    public LoginResult login(LoginRequest request) {
        captchaService.verify(request.captchaKey(), request.captchaCode());
        String phone = request.phone().trim();
        List<UserRow> users = jdbcTemplate.query("""
                SELECT id, username, password, real_name, phone, status, approval_status, deleted
                FROM sys_user WHERE phone = ? OR username = ? LIMIT 1
                """, (rs, rowNum) -> new UserRow(
                rs.getLong("id"), rs.getString("username"), rs.getString("password"), rs.getString("real_name"),
                rs.getString("phone"), rs.getString("status"), rs.getString("approval_status"), rs.getInt("deleted")
        ), phone, phone);
        if (users.isEmpty() || users.getFirst().deleted() == 1 || !passwordEncoder.matches(request.password(), users.getFirst().password())) {
            throw new BusinessException("手机号或密码错误");
        }
        UserRow user = users.getFirst();
        if (!"APPROVED".equals(user.approvalStatus()) || !"ENABLED".equals(user.status())) {
            throw new BusinessException("账号已禁用，请联系管理员");
        }
        jdbcTemplate.update("UPDATE sys_user SET last_login_time = CURRENT_TIMESTAMP WHERE id = ?", user.id());
        String token = jwtTokenProvider.createToken(user.id());
        return new LoginResult(token, session(user));
    }

    public AuthSessionResponse currentSession(Long userId) {
        List<UserRow> users = jdbcTemplate.query("""
                SELECT id, username, password, real_name, phone, status, approval_status, deleted
                FROM sys_user WHERE id = ? LIMIT 1
                """, (rs, rowNum) -> new UserRow(
                rs.getLong("id"), rs.getString("username"), rs.getString("password"), rs.getString("real_name"),
                rs.getString("phone"), rs.getString("status"), rs.getString("approval_status"), rs.getInt("deleted")
        ), userId);
        if (users.isEmpty() || users.getFirst().deleted() == 1) {
            throw new BusinessException("用户不存在");
        }
        return session(users.getFirst());
    }

    private AuthSessionResponse session(UserRow user) {
        return new AuthSessionResponse(
                new AuthUser(user.id(), user.username(), user.phone(), user.realName(), true),
                Set.of("*")
        );
    }

    public record LoginResult(String token, AuthSessionResponse session) {
    }

    private record UserRow(Long id, String username, String password, String realName, String phone,
                           String status, String approvalStatus, int deleted) {
    }
}
