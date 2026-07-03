package cn.datong.map.security;

public final class AuthCookies {
    public static final String AUTH_COOKIE = "DT_MAP_AUTH";
    public static final String CSRF_COOKIE = "XSRF-TOKEN";
    public static final String CSRF_HEADER = "X-XSRF-TOKEN";

    private AuthCookies() {
    }
}
