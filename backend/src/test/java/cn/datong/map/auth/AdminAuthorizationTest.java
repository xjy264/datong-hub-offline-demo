package cn.datong.map.auth;

import cn.datong.map.config.SecurityConfig;
import cn.datong.map.security.CsrfProtectionFilter;
import cn.datong.map.security.JwtAuthenticationFilter;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(AdminUserController.class)
@Import({SecurityConfig.class, AdminAuthorizationTest.TestBeans.class})
class AdminAuthorizationTest {
    @Autowired
    private MockMvc mvc;

    @Test
    void anonymousCannotListUsers() throws Exception {
        mvc.perform(get("/api/admin/users")).andExpect(status().isUnauthorized());
    }

    @Test
    void editorCannotListUsers() throws Exception {
        mvc.perform(get("/api/admin/users").with(user("editor").roles("EDITOR"))).andExpect(status().isForbidden());
    }

    @Test
    void adminCanListUsers() throws Exception {
        mvc.perform(get("/api/admin/users").with(user("admin").roles("ADMIN"))).andExpect(status().isOk());
    }

    @TestConfiguration
    static class TestBeans {
        @Bean
        AdminUserService adminUserService() {
            return new AdminUserService(null, null) {
                @Override
                public List<AdminUserView> listUsers() {
                    return List.of();
                }
            };
        }

        @Bean
        JwtAuthenticationFilter jwtAuthenticationFilter() {
            return new JwtAuthenticationFilter(null, null);
        }

        @Bean
        CsrfProtectionFilter csrfProtectionFilter() {
            return new CsrfProtectionFilter();
        }
    }
}
