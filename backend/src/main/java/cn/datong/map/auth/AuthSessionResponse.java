package cn.datong.map.auth;

import java.util.Set;

public record AuthSessionResponse(AuthUser user, Set<String> permissions) {
}
