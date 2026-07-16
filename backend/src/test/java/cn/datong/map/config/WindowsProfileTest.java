package cn.datong.map.config;

import org.junit.jupiter.api.Test;
import org.springframework.boot.env.YamlPropertySourceLoader;
import org.springframework.core.env.PropertySource;
import org.springframework.core.io.ClassPathResource;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class WindowsProfileTest {
    @Test
    void loadsSecureWindowsDefaultsWithoutRedisHealthDependency() throws Exception {
        List<PropertySource<?>> sources = new YamlPropertySourceLoader()
                .load("windows", new ClassPathResource("application-windows.yml"));

        assertThat(value(sources, "server.port")).isEqualTo("${SERVER_PORT:8012}");
        assertThat(value(sources, "server.ssl.enabled")).isEqualTo(true);
        assertThat(value(sources, "app.production")).isEqualTo(true);
        assertThat(value(sources, "app.auth.cookie-secure")).isEqualTo(true);
        assertThat(value(sources, "management.health.redis.enabled")).isEqualTo(false);
    }

    private Object value(List<PropertySource<?>> sources, String key) {
        return sources.stream().map(source -> source.getProperty(key)).filter(value -> value != null).findFirst().orElse(null);
    }
}
