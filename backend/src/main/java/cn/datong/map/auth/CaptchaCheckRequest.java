package cn.datong.map.auth;

import java.util.Map;

public record CaptchaCheckRequest(String id, Map<String, Object> data) {
}
