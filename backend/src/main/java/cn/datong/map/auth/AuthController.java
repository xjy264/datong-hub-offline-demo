package cn.datong.map.auth;

import cn.datong.map.common.ApiResponse;
import cn.datong.map.security.AuthCookies;
import cn.datong.map.security.SecurityUtils;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseCookie;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.security.SecureRandom;
import java.time.Duration;
import java.util.Base64;

@RestController
@RequestMapping("/api/auth")
public class AuthController {
    private final AuthService authService;
    private final boolean production;
    private final boolean cookieSecure;
    private final long jwtExpireSeconds;
    private final SecureRandom random = new SecureRandom();

    public AuthController(AuthService authService,
                          @Value("${app.production:false}") boolean production,
                          @Value("${app.auth.cookie-secure:false}") boolean cookieSecure,
                          @Value("${app.jwt.expire-seconds:86400}") long jwtExpireSeconds) {
        this.authService = authService;
        this.production = production;
        this.cookieSecure = cookieSecure;
        this.jwtExpireSeconds = jwtExpireSeconds;
    }

    @PostMapping("/register")
    public ApiResponse<Void> register(@Valid @RequestBody RegisterRequest request,
                                      HttpServletRequest servletRequest, HttpServletResponse response) {
        if (rejectInsecureProductionRequest(servletRequest, response)) {
            return ApiResponse.fail(426, "生产环境登录和注册必须使用HTTPS");
        }
        authService.register(request);
        return ApiResponse.success();
    }

    @PostMapping("/login")
    public ApiResponse<AuthSessionResponse> login(@Valid @RequestBody LoginRequest request,
                                                   HttpServletRequest servletRequest, HttpServletResponse response) {
        if (rejectInsecureProductionRequest(servletRequest, response)) {
            return ApiResponse.fail(426, "生产环境登录和注册必须使用HTTPS");
        }
        AuthService.LoginResult result = authService.login(request);
        setCookie(response, AuthCookies.AUTH_COOKIE, result.token(), true, Duration.ofSeconds(jwtExpireSeconds));
        setCookie(response, AuthCookies.CSRF_COOKIE, randomToken(), false, Duration.ofSeconds(jwtExpireSeconds));
        return ApiResponse.success(result.session());
    }

    @PostMapping("/logout")
    public ApiResponse<Void> logout(HttpServletResponse response) {
        clearCookie(response, AuthCookies.AUTH_COOKIE, true);
        clearCookie(response, AuthCookies.CSRF_COOKIE, false);
        return ApiResponse.success();
    }

    @GetMapping("/me")
    public ApiResponse<AuthSessionResponse> me() {
        return ApiResponse.success(authService.currentSession(SecurityUtils.currentUser().userId()));
    }

    private void setCookie(HttpServletResponse response, String name, String value, boolean httpOnly, Duration maxAge) {
        ResponseCookie cookie = ResponseCookie.from(name, value)
                .httpOnly(httpOnly)
                .secure(cookieSecure)
                .sameSite("Lax")
                .path("/")
                .maxAge(maxAge)
                .build();
        response.addHeader(HttpHeaders.SET_COOKIE, cookie.toString());
    }

    private void clearCookie(HttpServletResponse response, String name, boolean httpOnly) {
        setCookie(response, name, "", httpOnly, Duration.ZERO);
    }

    private String randomToken() {
        byte[] bytes = new byte[32];
        random.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private boolean rejectInsecureProductionRequest(HttpServletRequest request, HttpServletResponse response) {
        if (!production || request.isSecure() || "https".equalsIgnoreCase(request.getHeader("X-Forwarded-Proto"))) {
            return false;
        }
        response.setStatus(HttpStatus.UPGRADE_REQUIRED.value());
        return true;
    }
}
