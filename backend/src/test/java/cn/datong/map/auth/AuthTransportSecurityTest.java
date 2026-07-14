package cn.datong.map.auth;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Set;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.setup.MockMvcBuilders.standaloneSetup;

class AuthTransportSecurityTest {
    private final AuthService authService = mock(AuthService.class);

    @Test
    void productionRejectsLoginOverHttp() throws Exception {
        when(authService.login(any())).thenReturn(loginResult());
        MockMvc mvc = standaloneSetup(new AuthController(authService, true, true, 86400)).build();

        mvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"phone\":\"13800138000\",\"password\":\"Aa1!aaaa\"}"))
                .andExpect(status().isUpgradeRequired());
    }

    @Test
    void productionAllowsLoginForwardedFromHttpsProxy() throws Exception {
        when(authService.login(any())).thenReturn(loginResult());
        MockMvc mvc = standaloneSetup(new AuthController(authService, true, true, 86400)).build();

        mvc.perform(post("/api/auth/login")
                        .header("X-Forwarded-Proto", "https")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"phone\":\"13800138000\",\"password\":\"Aa1!aaaa\"}"))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.SET_COOKIE, containsString("Secure")));
    }

    @Test
    void productionRejectsRegistrationOverHttp() throws Exception {
        MockMvc mvc = standaloneSetup(new AuthController(authService, true, true, 86400)).build();

        mvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"realName\":\"张三\",\"phone\":\"13800138000\",\"password\":\"Aa1!aaaa\",\"confirmPassword\":\"Aa1!aaaa\"}"))
                .andExpect(status().isUpgradeRequired());
    }

    private AuthService.LoginResult loginResult() {
        AuthUser user = new AuthUser(1L, "admin", "13800138000", "管理员");
        return new AuthService.LoginResult("token", new AuthSessionResponse(user, Set.of("MAP_EDIT")));
    }
}
