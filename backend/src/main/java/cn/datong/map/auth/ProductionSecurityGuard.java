package cn.datong.map.auth;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

@Component
public class ProductionSecurityGuard implements ApplicationRunner {
    private final boolean production;
    private final boolean cookieSecure;

    public ProductionSecurityGuard(@Value("${app.production:false}") boolean production,
                                   @Value("${app.auth.cookie-secure:false}") boolean cookieSecure) {
        this.production = production;
        this.cookieSecure = cookieSecure;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (production && !cookieSecure) {
            throw new IllegalStateException("生产环境必须启用 AUTH_COOKIE_SECURE");
        }
    }
}
