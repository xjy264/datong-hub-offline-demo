package cn.datong.map.auth;

import cn.datong.map.common.BusinessException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.util.Base64;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class CaptchaService {
    public static final String SLIDER_PASSED_CODE = "SLIDER_PASSED";
    private static final String TRANSPARENT_PNG = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=";
    private final SecureRandom random = new SecureRandom();
    private final Map<String, Long> passed = new ConcurrentHashMap<>();
    private final String provider;

    public CaptchaService(@Value("${captcha.provider:none}") String provider) {
        this.provider = provider == null ? "none" : provider.trim().toLowerCase();
    }

    public Map<String, Object> create() {
        String id = randomToken();
        return Map.of(
                "id", id,
                "type", "SLIDER",
                "backgroundImage", TRANSPARENT_PNG,
                "templateImage", TRANSPARENT_PNG
        );
    }

    public Map<String, String> check(String id) {
        String key = id == null || id.isBlank() ? randomToken() : id;
        passed.put(key, System.currentTimeMillis() + 5 * 60 * 1000L);
        return Map.of("captchaKey", key, "captchaCode", SLIDER_PASSED_CODE);
    }

    public void verify(String key, String code) {
        if ("none".equals(provider) || "CAPTCHA_DISABLED".equals(key)) {
            return;
        }
        if (!SLIDER_PASSED_CODE.equals(code)) {
            throw new BusinessException("验证码错误或已过期");
        }
        Long expireAt = passed.remove(key);
        if (expireAt == null || expireAt < System.currentTimeMillis()) {
            throw new BusinessException("验证码错误或已过期");
        }
    }

    private String randomToken() {
        byte[] bytes = new byte[24];
        random.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }
}
