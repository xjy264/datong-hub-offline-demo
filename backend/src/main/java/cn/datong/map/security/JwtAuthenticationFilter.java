package cn.datong.map.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    private final JwtTokenProvider jwtTokenProvider;
    private final JdbcTemplate jdbcTemplate;

    public JwtAuthenticationFilter(JwtTokenProvider jwtTokenProvider, JdbcTemplate jdbcTemplate) {
        this.jwtTokenProvider = jwtTokenProvider;
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        String token = cookieValue(request.getCookies(), AuthCookies.AUTH_COOKIE);
        if (token != null) {
            try {
                Long userId = jwtTokenProvider.parseUserId(token);
                List<CurrentUser> users = jdbcTemplate.query("""
                        SELECT id FROM sys_user
                        WHERE id = ? AND deleted = 0 AND status = 'ENABLED' AND approval_status = 'APPROVED'
                        """, (rs, rowNum) -> new CurrentUser(rs.getLong("id")), userId);
                if (!users.isEmpty()) {
                    CurrentUser user = users.getFirst();
                    List<SimpleGrantedAuthority> authorities = List.of(new SimpleGrantedAuthority("ROLE_EDITOR"));
                    SecurityContextHolder.getContext().setAuthentication(
                            new UsernamePasswordAuthenticationToken(user, null, authorities));
                }
            } catch (Exception ignored) {
                SecurityContextHolder.clearContext();
            }
        }
        filterChain.doFilter(request, response);
    }

    private String cookieValue(Cookie[] cookies, String name) {
        if (cookies == null) return null;
        for (Cookie cookie : cookies) {
            if (name.equals(cookie.getName()) && cookie.getValue() != null && !cookie.getValue().isBlank()) {
                return cookie.getValue();
            }
        }
        return null;
    }
}
