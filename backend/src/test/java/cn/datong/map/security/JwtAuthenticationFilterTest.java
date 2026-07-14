package cn.datong.map.security;

import jakarta.servlet.http.Cookie;
import org.h2.jdbcx.JdbcDataSource;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.context.SecurityContextHolder;

import static org.assertj.core.api.Assertions.assertThat;

class JwtAuthenticationFilterTest {
    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void loadsApprovedEnabledUserWithEditorAuthority() throws Exception {
        JdbcDataSource dataSource = new JdbcDataSource();
        dataSource.setURL("jdbc:h2:mem:" + System.nanoTime() + ";MODE=MySQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1");
        JdbcTemplate jdbc = new JdbcTemplate(dataSource);
        jdbc.execute("CREATE TABLE sys_user (id BIGINT PRIMARY KEY, status VARCHAR(32), approval_status VARCHAR(32), is_super_admin TINYINT, deleted TINYINT)");
        jdbc.update("INSERT INTO sys_user VALUES (7, 'ENABLED', 'APPROVED', 1, 0)");
        JwtTokenProvider tokens = new JwtTokenProvider("01234567890123456789012345678901", 86400);
        JwtAuthenticationFilter filter = new JwtAuthenticationFilter(tokens, jdbc);
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/maps");
        request.setCookies(new Cookie(AuthCookies.AUTH_COOKIE, tokens.createToken(7L)));

        filter.doFilter(request, new MockHttpServletResponse(), (req, response) -> { });

        CurrentUser user = (CurrentUser) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        assertThat(user.userId()).isEqualTo(7L);
        assertThat(SecurityContextHolder.getContext().getAuthentication().getAuthorities())
                .extracting("authority")
                .containsExactly("ROLE_EDITOR");
    }
}
